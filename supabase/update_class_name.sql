begin;
create or replace function public.rename_class(p_class_id uuid,p_name text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare updated_name text;
begin
 if auth.uid() is null or not public.is_admin() then raise exception '진행자 로그인이 필요합니다'; end if;
 if p_name is null or length(trim(p_name)) < 1 or length(trim(p_name)) > 100 then raise exception '클래스 이름은 1자 이상 100자 이하여야 합니다'; end if;
 update public.classes set name=trim(p_name) where id=p_class_id and owner_id=auth.uid() returning name into updated_name;
 if not found then raise exception '클래스를 찾을 수 없거나 변경 권한이 없습니다'; end if;
 return jsonb_build_object('name',updated_name);
end $$;
revoke all on function public.rename_class(uuid,text) from public,anon;
grant execute on function public.rename_class(uuid,text) to authenticated;
commit;
