-- 기존 데이터 보존: 클래스 소유자만 조 수를 조정할 수 있습니다.
begin;
create or replace function public.set_class_team_count(p_class_id uuid, p_count integer)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare current_count integer; blocked text;
begin
 if auth.uid() is null or not public.is_admin() then raise exception '진행자 로그인이 필요합니다'; end if;
 if p_count is null or p_count < 1 or p_count > 30 then raise exception '조 개수는 1에서 30 사이여야 합니다'; end if;
 perform 1 from public.classes where id=p_class_id and owner_id=auth.uid() for update;
 if not found then raise exception '클래스를 찾을 수 없거나 변경 권한이 없습니다'; end if;
 -- 조 입장 및 저장과 직렬화하여 검사 후 삭제 사이의 데이터 유실을 방지합니다.
 perform 1 from public.teams where class_id=p_class_id order by number for update;
 select count(*) into current_count from public.teams where class_id=p_class_id;
 if p_count < current_count then
   select string_agg(t.number::text || '조', ', ' order by t.number) into blocked
   from public.teams t where t.class_id=p_class_id and t.number>p_count
    and (t.version > 0 or exists(select 1 from public.team_members m where m.team_id=t.id));
   if blocked is not null then raise exception '%는 참여 기록 또는 저장된 내용이 있어 삭제할 수 없습니다. 조별 결과를 보존하기 위해 조 수를 변경하지 않았어요.',blocked; end if;
   delete from public.teams where class_id=p_class_id and number>p_count;
 end if;
 insert into public.teams(class_id,number)
 select p_class_id, n from generate_series(1,p_count) as g(n)
 on conflict (class_id,number) do nothing;
 return jsonb_build_object('count',p_count);
end $$;
revoke all on function public.set_class_team_count(uuid,integer) from public,anon;
grant execute on function public.set_class_team_count(uuid,integer) to authenticated;
commit;
