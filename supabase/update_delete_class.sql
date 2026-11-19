-- 실행만으로 삭제하지 않습니다. 클래스 소유자의 명시적인 함수 호출에서만 삭제합니다.
begin;
create or replace function public.delete_class_confirmed(p_class_id uuid, p_confirm_name text)
returns void language plpgsql security definer set search_path=public,auth as $$
declare actual_name text;
begin
 if auth.uid() is null or not public.is_admin() then raise exception '진행자 로그인이 필요합니다'; end if;
 select name into actual_name from public.classes where id=p_class_id and owner_id=auth.uid() for update;
 if not found then raise exception '클래스를 찾을 수 없거나 삭제 권한이 없습니다'; end if;
 if p_confirm_name is null or p_confirm_name<>actual_name then raise exception '클래스 이름이 일치하지 않습니다. 새로고침 후 다시 확인해 주세요'; end if;
 -- 조, 조별 작성 데이터, 참여 기록은 기존 ON DELETE CASCADE로 함께 삭제됩니다.
 delete from public.classes where id=p_class_id and owner_id=auth.uid();
end $$;
revoke all on function public.delete_class_confirmed(uuid,text) from public,anon;
grant execute on function public.delete_class_confirmed(uuid,text) to authenticated;
commit;
