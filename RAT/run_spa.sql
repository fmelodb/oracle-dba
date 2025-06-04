
-- Language: PT-BR

-- Documentação Oficial: https://docs.oracle.com/en/database/oracle/oracle-database/19/ratug/sql-performance-analyzer.html#GUID-8CE976A3-FB73-45FF-9B18-A6AB3F158A95
-- Nota: sempre ler MOS Doc ID 560977.1 antes de usar o RAT

---------------------------------------------------------
--- Captura de SQL Tuning Sets e Teste ---
---------------------------------------------------------
------------------ Usando SPA APIs ----------------------
---------------------------------------------------------

-----------------------------------
--- # DATABASE DE ORIGEM # ---
-----------------------------------

-- 1. Criar SQL Tuning SET
EXEC DBMS_SQLTUNE.CREATE_SQLSET(sqlset_name => 'my_workload', description  => 'STS para armazenar SQL statements' );

-- 2. Execute agora os SQL statements e/ou processos que pretende comparar
-- Certifique-se de que o AWR está habilitado e coletando, se possível com intervalo pequeno (de 10 ou 15 minutos)

-- 3. Após execução, fazer a carga dos SQLs no STS -- pode ser a partir do repositório AWR, ou do Cursor Cache:
-- a) Carregar STS com dados do AWR
DECLARE
  cur sys_refcursor;
  snap_ini int := 1; -- definir snap ini
  snap_fim int := 2; -- definir snap fim
BEGIN
  OPEN cur FOR
  SELECT VALUE(P) FROM table(DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY(snap_ini,snap_fim)) P; 
  
  DBMS_SQLTUNE.LOAD_SQLSET(sqlset_name => 'my_workload', populate_cursor => cur);
END;
/

-- b) Ou Carregar STS com dados do Cursor CACHE
DECLARE
    v_cursor  DBMS_SQLTUNE.sqlset_cursor;
BEGIN
    OPEN v_cursor FOR
    SELECT VALUE(a) FROM TABLE(DBMS_SQLTUNE.select_cursor_cache) a;
                                               
    DBMS_SQLTUNE.load_sqlset(sqlset_name  => 'my_workload', populate_cursor => v_cursor);
END;
/


-- Listar STS coletados se necessário
COLUMN SQL_TEXT FORMAT a30   
COLUMN SCH FORMAT a3
COLUMN ELAPSED FORMAT 999999999

SELECT SQL_ID, PARSING_SCHEMA_NAME AS "SCH", SQL_TEXT, 
       ELAPSED_TIME AS "ELAPSED", BUFFER_GETS
FROM   TABLE( DBMS_SQLTUNE.SELECT_SQLSET( 'my_workload' ) );


-- 4. Criar Staging Table no 12.1 para exportar STS
EXEC DBMS_SQLTUNE.CREATE_STGTAB_SQLSET ( table_name  => 'MY_STAGING_TABLE' );

-- 5. Popular a Staging TABLE com os SQL Tuning Sets
EXEC DBMS_SQLTUNE.PACK_STGTAB_SQLSET ( sqlset_name => 'my_workload', staging_table_name  => 'MY_STAGING_TABLE' )

-- 6. Executar se *** mudar *** o DBID da origem e destino (ou arquitetura Non-CDB para CDB)
-- Se utilizar PDB, pegue o CON_DBID pela coluna DBID da view v$pdbs (conectado no pdb)

var old_dbid int -- source dbid
var new_dbid int -- source dbid

exec :old_dbid := 1234 -- source dbid
exec :new_dbid := 5678 -- target dbid

EXEC DBMS_SQLTUNE.REMAP_STGTAB_SQLSET ( staging_table_name => 'MY_STAGING_TABLE', -
                                        old_sqlset_name => 'my_workload', -
					                              old_con_dbid => :old_dbid, -
					                              new_con_dbid => :new_dbid);

-- Exporta a tabela stage
-- 7. Crie um directory para o export (create directory dpump_dir as '/tmp';)

-- expdp DIRECTORY=dpump_dir DUMPFILE=sts.dmp TABLES=MY_STAGING_TABLE

-- 8. Transfere dump para o destino


-------------------------------------------------------
--- # DATABASE DE DESTINO # ---
-------------------------------------------------------

-- Os dados/tabelas devem existir no destino

-- Importa a tabela stage
-- 9. Crie um directory para o export (create directory dpump_dir as '/tmp';)

-- impdp DIRECTORY=dpump_dir DUMPFILE=sts.dmp TABLES=MY_STAGING_TABLE 

-- 10. Obtem os STS da staging table
EXEC DBMS_SQLTUNE.UNPACK_STGTAB_SQLSET ( sqlset_name => '%', replace => true, staging_table_name => 'MY_STAGING_TABLE');

-- 11. Cria a Analysis Task
VARIABLE t_name VARCHAR2(100);
EXEC :t_name := DBMS_SQLPA.CREATE_ANALYSIS_TASK(task_name => 'MySPATask', sqlset_name => 'my_workload')

-- 12. Cria o BEFORE_CHANGE a partir do STS
EXEC DBMS_SQLPA.RESET_ANALYSIS_TASK('MySPATask');
EXEC DBMS_SQLPA.EXECUTE_ANALYSIS_TASK(task_name => 'MySPATask', execution_type => 'CONVERT SQLSET', execution_name => 'BEFORE_CHANGE');

-- 13. Cria o AFTER_CHANGE a partir do ambiente atual (com eventual mudança ou upgrade)
EXEC DBMS_SQLPA.EXECUTE_ANALYSIS_TASK(task_name => 'MySPATask', execution_type => 'TEST EXECUTE', execution_name => 'AFTER_CHANGE');

-- 14. Compara a performance
EXEC DBMS_SQLPA.EXECUTE_ANALYSIS_TASK(task_name => 'MySPATask', execution_type => 'COMPARE PERFORMANCE', execution_name => 'COMPARE_PERFORMANCE');

-- 15. Checa as execuções
set lines 150
col execution_name format a20
col execution_type format a20
col advisor_name format a30
col status format a10		
SELECT execution_name, 
       execution_type, 
       TO_CHAR(execution_start,'dd-mon-yyyy hh24:mi:ss') AS execution_start,
       TO_CHAR(execution_end,'dd-mon-yyyy hh24:mi:ss') AS execution_end, 
       advisor_name, 
       status
FROM dba_advisor_executions
WHERE task_name='MySPATask';

-- 16. Gera o report de comparação
set trimspool on
set trim on
set pages 0
set linesize 1000
set long 1000000
set longchunksize 1000000
spool MySPATask_compare_performance.html
SELECT DBMS_SQLPA.REPORT_ANALYSIS_TASK('MySPATask', 'HTML', 'ALL', 'ALL') FROM dual;
spool off