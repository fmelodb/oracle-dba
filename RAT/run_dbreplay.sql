-- Language: PT-BR

-- Documentação Oficial: https://docs.oracle.com/en/database/oracle/oracle-database/19/ratug/database-replay.html#GUID-C5CAF3E6-0F1C-4BD6-BC03-F71744AD600E
-- Nota: sempre ler MOS Doc ID 560977.1 antes de usar o RAT

---------------------------------------------------------
--- Captura de Workload e Replay no 19c ---
---------------------------------------------------------
------------- Usando DB Replay APIs ---------------------
---------------------------------------------------------

-----------------------------------
--- # DATABASE DE ORIGEM # ---
-----------------------------------

-- 1. Criar um directory onde vão ficar os arquivos da captura
-- Deve ter espaço suficiente para o tempo da captura

CREATE DIRECTORY capdir as '/tmp';

-- 2. Adicione um filtro se necessário
BEGIN
  DBMS_WORKLOAD_CAPTURE.ADD_FILTER (
                           fname => 'FiltroDeUsuario',
                           fattribute => 'USER',
                           fvalue => 'FMELO');
END;
/

-- Garanta que não há nada executando no banco (se for possível fazer reboot, faça)

-- 3. Inicie a captura
BEGIN
  DBMS_WORKLOAD_CAPTURE.START_CAPTURE (name => 'CapturaProcessoX', 
                                       dir => 'capdir',
                                       capture_sts => TRUE,
				       sts_cap_interval => 300,
                                       plsql_mode => 'extended');
END;
/


-- 4. Execute o workload/processo/job/batch/consultas neste momento


-- 5. Interrompa a captura ao finalizar o workload
BEGIN
  DBMS_WORKLOAD_CAPTURE.FINISH_CAPTURE(); 
END;
/

-- 6. Obtenha o código da captura e depois exporte o AWR
var capture_id int
SELECT max(id) into :capture_id from DBA_WORKLOAD_CAPTURES;

BEGIN
  DBMS_WORKLOAD_CAPTURE.EXPORT_AWR (capture_id => :capture_id);
END;
/



-------------------------------------------------------
--- # DATABASE DE DESTINO # ---
-------------------------------------------------------

-- 7. Retorne o banco de dados no ponto do tempo onde a captura foi iniciada

-- 8. Criar um directory onde vão ficar os arquivos da captura
-- Transfira os arquivos capturados na origem para este diretório no destino
CREATE DIRECTORY capdir as '/tmp';

-- 9. Crie um usuário para carregar os dados do AWR
CREATE USER capture_awr IDENTIFIED BY password
GRANT DBA to capture_awr;

-- 10. Realize o preprocessamento da captura e carregue o AWR
-- Obs: remover o parâmetro plsql_mode se sua versão for inferior a 12.2

BEGIN
  DBMS_WORKLOAD_REPLAY.PROCESS_CAPTURE (capture_dir => 'capdir',
                                        plsql_mode => 'extended');
END;
/

SELECT DBMS_WORKLOAD_CAPTURE.IMPORT_AWR (capture_id => :capture_id,  -- utilize o mesmo ID do export do AWR
                                         staging_schema => 'capture_awr')  -- schema deve estar vazio
  FROM DUAL;

-- 11. Execute o Workload Analyzer 
-- exemplo de comando:

/*
java -classpath
$ORACLE_HOME/jdbc/lib/ojdbc6.jar:$ORACLE_HOME/rdbms/jlib/dbrparser.jar:
$ORACLE_HOME/rdbms/jlib/dbranalyzer.jar:
oracle.dbreplay.workload.checker.CaptureChecker /tmp
jdbc:oracle:thin:@myhost.mycompany.com:1521:orcl
*/


-- Obs: Vai pedir um usuário e senha (utilize algum usuário com permissão de EXECUTE em DBMS_WORKLOAD_CAPTURE e SELECT_CATALOG_ROLE)
-- Obs: o preprocessamento deve ocorrer somente uma vez na mesma versão do banco que vai rodar o replay
-- Obs: Analisar wcr_cap_analysis.html gerado no diretório da captura para verificar se há erros

-- copiar os dados no diretório de captura para um diretório em um host a parte que vai processar o replay
-- deve ter um client oracle instalado

-- 12. No banco de dados do replay, executar:
-- Obs: remover o parâmetro plsql_mode se sua versão for inferior a 12.2

BEGIN
  DBMS_WORKLOAD_REPLAY.INITIALIZE_REPLAY (replay_name => 'replay_ProcessoX',
                                          replay_dir => 'capdir',
                                          plsql_mode => 'extended');
END;
/

-- 13. Remapear as conexões para o destino (se não remapear, os clients vão apontar para a origem)
-- Após inicializar o replay, checar view DBA_WORKLOAD_CONNECTION_MAP
var conn_id int
exec :conn_id := 12345;
BEGIN
  DBMS_WORKLOAD_REPLAY.REMAP_CONNECTION (connection_id => :conn_id,
                                         replay_connection => 'host:porta/service_name');
END;
/

-- 14. Configurando as opções do REPLAY
BEGIN
  DBMS_WORKLOAD_REPLAY.PREPARE_REPLAY (synchronization => 'TIME',
                                       capture_sts => TRUE,
                                       sts_cap_interval => 300);
END;
/

-- 15. No host dos clients (não é o host do banco de dados), executar o calibrate para identificar quantos clients são necessários
-- replaydir é o diretório no host a parte que tem os arquivos preprocessados (substitua se o seu for diferente)

-- Execute no terminal do host dos clients:
-- wrc mode=calibrate replaydir=./replay

-- 16. No host dos clients (não é o host do banco de dados), iniciar clients para o replay de acordo com a quantidade informada no calibrate (se informar 3, repetir a prox linha 3 vezes)
-- ex:
-- nohup wrc system/password@test mode=replay replaydir=./replay &
-- nohup wrc system/password@test mode=replay replaydir=./replay &
-- nohup wrc system/password@test mode=replay replaydir=./replay &

-- 17. No banco de dados, inicie o Replay
BEGIN
  DBMS_WORKLOAD_REPLAY.START_REPLAY();
END;
/

-- Veja a view DBA_WORKLOAD_REPLAYS para o status do REPLAY

-- 18. Exportar AWR e STS do REPLAY se necessário
var replay_id int
exec :replay_id := 1234
BEGIN
  DBMS_WORKLOAD_REPLAY.EXPORT_AWR(replay_id => :replay_id);
END;
/

-- 19. Compare Periods Report (Capture vs Replay)
SET PAGESIZE 0
SET TRIMSPOOL ON
SET LINESIZE 500
SET FEEDBACK OFF
SET LONG 1000000
SET SERVEROUTPUT ON

VAR v_clob CLOB
BEGIN
	dbms_workload_replay.compare_period_report(replay_id1 => :replay_id,
                                               replay_id2 => NULL, -- compara contra a captura
                                               format => DBMS_WORKLOAD_REPLAY.TYPE_HTML,
                                               result => :v_clob);
END;
/
spool compare_periods.html
PRINT v_clob
spool off


-- 20. Compare STS Report
SET PAGESIZE 0
SET TRIMSPOOL ON
SET LINESIZE 500
SET FEEDBACK OFF
SET LONG 1000000
VAR v_clob CLOB
DECLARE
   l_result VARCHAR2(200);
BEGIN
   l_result := dbms_workload_replay.compare_sqlset_report(replay_id1 => :replay_id,
                                                          replay_id2 => NULL, -- compara contra a captura
                                                          format => DBMS_WORKLOAD_REPLAY.TYPE_HTML,
                                                          result => :v_clob);
END;
/
SPOOL compare_sts.html
PRINT v_clob
SPOOL OFF