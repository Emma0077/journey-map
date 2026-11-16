-- 기존 클래스·여정 데이터를 보존하는 업데이트. Supabase SQL Editor에서 한 번 실행하세요.
begin;
alter table public.classes add column if not exists short_code text;
update public.classes set short_code = encode(gen_random_bytes(5), 'hex') where short_code is null;
create unique index if not exists classes_short_code_unique on public.classes(short_code);
alter table public.classes alter column short_code set default encode(gen_random_bytes(5), 'hex');
alter table public.classes alter column short_code set not null;

create or replace function public.class_landing(p_token text) returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare output jsonb;
begin
 select jsonb_build_object('name',c.name,'short_code',c.short_code,'teams',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'number',t.number) order by t.number) from public.teams t where t.class_id=c.id),'[]'::jsonb)) into output from public.classes c where c.invite_token=p_token or c.short_code=lower(p_token);
 if output is null then raise exception '유효하지 않은 클래스 링크입니다'; end if;
 return output;
end $$;

create or replace function public.admin_class(p_id uuid) returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare output jsonb;
begin
 if not public.is_admin() then raise exception '관리자 권한이 필요합니다'; end if;
 select jsonb_build_object('id',c.id,'name',c.name,'token',c.invite_token,'short_code',c.short_code,'teams',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'number',t.number,'doc',t.doc,'version',t.version,'updated_at',t.updated_at,'member_count',(select count(*) from public.team_members m where m.team_id=t.id)) order by t.number) from public.teams t where t.class_id=c.id),'[]'::jsonb)) into output from public.classes c where c.id=p_id and c.owner_id=auth.uid();
 if output is null then raise exception '클래스를 찾을 수 없습니다'; end if;
 return output;
end $$;

-- 공유 링크를 가진 사람이 조에 입장합니다. 입장 코드와 기기 수 제한은 없습니다.
create or replace function public.join_team_by_number(p_token text,p_number integer) returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare t public.teams;
begin
 if auth.uid() is null then raise exception '로그인이 필요합니다'; end if;
 select tm.* into t from public.teams tm join public.classes c on c.id=tm.class_id where (c.invite_token=p_token or c.short_code=lower(p_token)) and tm.number=p_number for update of tm;
 if not found then raise exception '해당 조를 찾을 수 없습니다'; end if;
 insert into public.team_members(team_id,user_id) values(t.id,auth.uid()) on conflict do nothing;
 return jsonb_build_object('id',t.id,'number',t.number,'doc',t.doc,'version',t.version);
end $$;
revoke all on function public.join_team_by_number(text,integer) from public,anon;
grant execute on function public.join_team_by_number(text,integer) to authenticated;
-- 구 버전의 조별 입장 코드 기능은 더 이상 사용하지 않습니다.
revoke execute on function public.join_team(text,uuid,text) from anon,authenticated;
commit;
