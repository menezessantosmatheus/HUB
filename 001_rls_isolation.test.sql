begin;
select plan(9);

-- Usuários de teste
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-00000000000a','a@teste.com'),
 ('00000000-0000-0000-0000-00000000000b','b@teste.com'),
 ('00000000-0000-0000-0000-00000000000c','c@teste.com');

-- Empresa A (dono A) e Empresa B (dono B), criadas via função oficial
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-00000000000a"}',true);
select public.create_company('Adega A','Loja A1');
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-00000000000b"}',true);
select public.create_company('Adega B','Loja B1');

-- 1) B só enxerga a própria empresa
select is((select count(*) from public.companies)::int, 1, 'B vê apenas 1 empresa');
select is((select name from public.companies), 'Adega B', 'B vê Adega B');

-- 2) A só enxerga as próprias lojas
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-00000000000a"}',true);
select is((select count(*) from public.stores)::int, 1, 'A vê apenas 1 loja');
select is((select count(*) from public.stores where name = 'Loja B1')::int, 0, 'A não vê loja de B');

-- 3) A não consegue alterar empresa de B
update public.companies set name = 'HACK' where name = 'Adega B';
select is((select count(*) from public.companies where name='HACK')::int, 0, 'A não altera B');

-- 4) Usuário sem vínculo não vê nada
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-00000000000c"}',true);
select is((select count(*) from public.companies)::int, 0, 'C (sem vínculo) não vê empresas');
select is((select count(*) from public.stores)::int, 0, 'C não vê lojas');

-- 5) Auditoria não pode ser inserida diretamente
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-00000000000a"}',true);
select throws_ok(
  $$insert into public.audit_logs (company_id, action, entity) select id,'x','y' from public.companies$$,
  '42501', null, 'Ninguém insere audit_logs direto');

-- 6) Toda tabela do schema public tem RLS ligada
reset role;
select is((select count(*) from pg_tables t join pg_class c on c.relname = t.tablename
           where t.schemaname='public' and not c.relrowsecurity)::int, 0,
          'Nenhuma tabela pública sem RLS');

select * from finish();
rollback;
