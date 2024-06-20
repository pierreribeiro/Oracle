-- script discovery_oracle.sql 


/*

	-- INSTRUÇÕES SCRIPT  discovery_oracle.sql
	-- Rodar este script no SQLPLUS; caso seja executado no sqldeveloper, rodar como “script” (tecla F5). 
		-- exemplo: 
			-- @discovery_oracle.sql  
			
	-- O RESULTADO DEVE SER ENTREGUE EM FORMATO “TXT”. 

*/

-- parametros sqlplus
set feed off 
set timing off 
set echo off 
set lines 300 pages 9999	
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';

-- spoolling 
spo resultados_discovery.txt 


/* *** DADOS GERAIS *** */ 
-- NOME DO BANCO e outras caracteristicas 
select name, dbid, log_mode, force_logging,  flashback_on, GUARD_STATUS, CONTROLFILE_TYPE, SWITCHOVER_STATUS
from v$database; 
prompt 

-- VERSAO DO BANCO DE DADOS 
col BANNER for a100 
prompt	VERSAO 
select banner from v$version 
union 
select dbms_utility.port_string from dual;
prompt 

-- DADOS DE INSTANCIA 
prompt INSTANCIAS 
select inst_id, status, instance_name, host_name 
from gv$instance;

-- cluster database 
col name for a70  
col value for a110
prompt ORACLE RAC PARAMETER 
SELECT inst_id, 
	 substr(name,0,512) name
	,NVL(SUBSTR(value,0,512) , 'null value') value 
  FROM  gv$parameter
  where name in ('cluster_database','cluster_database_instances');
prompt 


-- TAMANHO DO BANCO DE DADOS 
prompt TAMANHO DO BANCO DE DADOS
col size_gb for 99999999999
break on report
compute sum of size_gb on report
	select 'datafile' name, round(sum(bytes)/1024/1024/1024,2) size_gb from v$datafile
	union 
	select 'tempfile' name, round(sum(bytes)/1024/1024/1024,2) size_gb from v$tempfile
	union
	select 'controlfile' name, (BLOCK_SIZE*FILE_SIZE_BLKS)/1024/1024/1024 size_gb from v$controlfile;
prompt 


-- cdb_pdbs
prompt FEATURES: Multinenant 
SELECT CDB FROM V$DATABASE;
prompt 
prompt PDBS
col name for a15 
SELECT NAME, CON_ID, DBID, CON_UID, GUID 
	FROM V$CONTAINERS 
	ORDER BY CON_ID;
prompt 


/* *** DADOS DE MEMORIA *** */

-- ADVICE SGA 
-- obs: parâmetro sga_target precisa estar configurado. 
prompt SGA INFO 
COL  SGA_SIZE FOR 999999999999999
COL ESTD_PHYSICAL_READS FOR 999999999999999
SELECT inst_id, SGA_SIZE_FACTOR, SGA_SIZE,  ESTD_PHYSICAL_READS 
FROM gv$sga_target_advice;   
prompt   

-- ADVICE PGA 
prompt PGA INFO 
COL PGA_TARGET_FOR_ESTIMATE FOR 999999999999999
COL ESTD_EXTRA_BYTES_RW FOR 999999999999999
SELECT inst_id, 
	PGA_TARGET_FACTOR, PGA_TARGET_FOR_ESTIMATE,
	ESTD_PGA_CACHE_HIT_PERCENTAGE,
	ESTD_EXTRA_BYTES_RW, ESTD_OVERALLOC_COUNT
	FROM gV$PGA_TARGET_ADVICE ORDER BY 1;
prompt 


/* *** DADOS DE CPU  ***/ 

-- CPU_COUNT 
col name for a70  
col value for a110
prompt ORACLE RAC PARAMETER 
SELECT inst_id, 
	 substr(name,0,512) name
	,NVL(SUBSTR(value,0,512) , 'null value') value 
  FROM  gv$parameter
  where name in ('cpu_count');
  ORDER BY 1,2;
prompt 


-- OS STAT   
COL VALUE FOR 999999999999999	
SELECT * FROM GV$OSSTAT;	
prompt 

-- ESTATÍSTICAS DE S.O.
col STAT_NAME form A30
col VALUE form a10
col comments form a70
prompt CPU e MEMORIA 
select STAT_NAME,
		to_char(VALUE) as VALUE
	from v$osstat 
	where stat_name  IN ('NUM_CPUS','NUM_CPU_CORES','NUM_CPU_SOCKETS')
union
	select STAT_NAME,
			round(VALUE/1024/1024/1024,2) || ' GB'   
		from v$osstat 
		where stat_name  IN ('PHYSICAL_MEMORY_BYTES');
prompt 

-- DEMAIS UTILIZACOES DO BANCO DE DADOS
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';
prompt CONSUMO DE CPU E I/O 
SELECT INSTANCE_NUMBER,
       min(to_char(begin_time, 'dd-mm-yyyy-hh24:mi')) inicio,
       max(to_char(end_time, 'dd-mm-yyyy-hh24:mi')) fim,
       round(sum(case metric_name when 'Host CPU Utilization (%)' then average end),1) Host_CPU_util,
       round(sum(case metric_name when 'Physical Read Total Bytes Per Sec' then average end) / 1024 / 1024, 1) Physical_Read_MBps,
       round(sum(case metric_name when 'Physical Write Total Bytes Per Sec' then average end) / 1024 / 1024, 1) Physical_Write_MBps,
       round(sum(case metric_name when 'Physical Read Total IO Requests Per Sec' then average  end), 1) Physical_Read_IOPS,
       round(sum(case metric_name when 'Physical Write Total IO Requests Per Sec' then average end), 1) Physical_write_IOPS,
       round(sum(case metric_name when 'Redo Writes Per Sec' then average end), 1) Physical_redo_IOPS,
       round(sum(case metric_name when 'Network Traffic Volume Per Sec' then average end) / 1024 / 1024, 1) Network_Mb_per_sec,
       snap_id
  from dba_hist_sysmetric_summary
where trunc(begin_time) > trunc(sysdate - 30)
group by INSTANCE_NUMBER,snap_id
order by INSTANCE_NUMBER,snap_id;
prompt 
prompt fim  CONSUMO DE CPU E I/O
prompt
prompt 


/* *** backup *** */ 
prompt BACKUP 
set line 200 pages 999
col inicio form a20
col termino form a20
select * from (
	select INPUT_TYPE, 
	to_char(START_TIME,'DD-MM-YYYY HH24:MI:SS') as INICIO, 
	to_char(END_TIME,'DD-MM-YYYY HH24:MI:SS') as TERMINO,
	ELAPSED_SECONDS sec,  -- melhorar esta coluna 
	TRUNC((END_TIME - START_TIME)*24*60) as TEMP_MIN,
	round(INPUT_BYTES/1024/1024/1024) as "INPUT SIZE(GB)", 
	round(OUTPUT_BYTES/1024/1024/1024) as "BKP SIZE(GB)", 
	round(COMPRESSION_RATIO) as "COMPRESS RATIO",
	OUTPUT_DEVICE_TYPE as DEVICE, 
	STATUS
from v$RMAN_BACKUP_JOB_DETAILS
	order by start_time desc)
	where rownum < 180;
set pages 999
prompt 



-- REDO LOG 
prompt REDO LOG
prompt 
prompt REDO LOG: TAMANHO DOS REDOS POR THREAD 
select db.name, thread#,  count(*), bytes/1024/1024 as tam_MB 
	from v$log,
		 v$database db 
	group by bytes, thread#, db.name;
	
	
prompt REDO LOG:	Historico de archived_log / dia
select THREAD#,
		to_char(COMPLETION_TIME,'MM-DD') "MM-DD",
		count(*) QTD, 
		round(sum(BLOCKS*BLOCK_SIZE)/1024/1024) SIZE_MB 
	from v$archived_log 
	group by THREAD#,to_char(COMPLETION_TIME,'MM-DD') 
	order by 1,2;
prompt 

prompt REDO LOG: UTILIZACAO DETALHADA 
select 
    to_char(first_time,'DD-MM-YYYY') day,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'00',1,0)),'99') hour_00,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'01',1,0)),'99') hour_01,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'02',1,0)),'99') hour_02,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'03',1,0)),'99') hour_03,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'04',1,0)),'99') hour_04,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'05',1,0)),'99') hour_05,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'06',1,0)),'99') hour_06,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'07',1,0)),'99') hour_07,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'08',1,0)),'99') hour_08,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'09',1,0)),'99') hour_09,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'10',1,0)),'99') hour_10,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'11',1,0)),'99') hour_11,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'12',1,0)),'99') hour_12,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'13',1,0)),'99') hour_13,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'14',1,0)),'99') hour_14,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'15',1,0)),'99') hour_15,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'16',1,0)),'99') hour_16,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'17',1,0)),'99') hour_17,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'18',1,0)),'99') hour_18,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'19',1,0)),'99') hour_19,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'20',1,0)),'99') hour_20,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'21',1,0)),'99') hour_21,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'22',1,0)),'99') hour_22,
    to_char(sum(decode(substr(to_char(first_time,'DDMMYYYY:HH24:MI'),10,2),'23',1,0)),'99') hour_23
from
    v$log_history 
group by
    to_char(first_time,'DD-MM-YYYY')
order by
    1;
prompt 


/*** PERFORMANCE - Perfil de uso com ASH 1h***/ 
PROMPT  PERFORMANCE 

SELECT
     to_char(TRUNC(sample_time,'MI'),'DD-MM-RR-HH24:MI') AS sample_time,
     SUM(DECODE(session_state,'ON CPU',DECODE(session_type,'BACKGROUND',0,1),0))/60 AS CPU,
     SUM(DECODE(session_state,'ON CPU',DECODE(session_type,'BACKGROUND',1,0),0))/60 AS BCPU,
     SUM(DECODE(wait_class,'Scheduler',1,0))/60 AS "Scheduler",
     SUM(DECODE(wait_class,'User I/O',1,0))/60 AS "User_I/O",
     SUM(DECODE(wait_class,'System I/O',1,0))/60 AS "System_I/O",
     SUM(DECODE(wait_class,'Concurrency',1,0))/60 AS "Concurrency",
     SUM(DECODE(wait_class,'Application',1,0))/60 AS "Application",
     SUM(DECODE(wait_class,'Commit',1,0))/60 AS "Commit",
     SUM(DECODE(wait_class,'Configuration',1,0))/60 AS "Configuration",
     SUM(DECODE(wait_class,'Administrative',1,0))/60 AS "Administrative",
     SUM(DECODE(wait_class,'Network',1,0))/60 AS "Network",
     SUM(DECODE(wait_class,'Queueing',1,0))/60 AS "Queueing",
     SUM(DECODE(wait_class,'Cluster',1,0))/60 AS "Cluster",
     SUM(DECODE(wait_class,'Other',1,0))/60 AS "Other"
   FROM v$active_session_history
   WHERE sample_time>sysdate - INTERVAL '1' HOUR
   AND sample_time<=TRUNC(SYSDATE,'MI')
   GROUP BY TRUNC(sample_time,'MI')
   order by 1;



/* *** PARAMETROS  *** */

-- DADOS DE NLS 
col PARAMETER for a40
prompt NLS PARAMETERS 
SELECT a.*
  FROM NLS_DATABASE_PARAMETERS a;
prompt 


-- PARAMETROS DO BANCO DE DADOS 
prompt PARAMETROS DB 
Set line 200
col PROPERTY_NAME for a40  
col PROPERTY_VALUE form a80
select 	PROPERTY_NAME,
		PROPERTY_VALUE 
from database_properties
order by 1;
prompt 


-- PARAMETROS DAS INSTANCIAS
col name for a70  
col value for a110
prompt INSTANCES PARAMETERS  
SELECT inst_id, 
	 substr(name,0,512) name
	,NVL(SUBSTR(value,0,512) , 'null value') value 
  FROM  gv$parameter
  ORDER BY 1,2;
prompt 


/* *** DADOS DE UTILIZACAO DE FEATURES  *** */

-- in memory 
prompt FEATURES: IN-MEMORY (cdb) 
select distinct inmemory from cdb_tables;
prompt 

-- particionamento 
prompt FEATURES:  
select * from v$option order by 1;
select name, version, last_usage_date,currently_used from DBA_FEATURE_USAGE_STATISTICS order by 1;
prompt 


-- licenciamento 
prompt SESSOES, ETC do cluster 
SELECT a.*   
	FROM gv$license a;
prompt 

SELECT avg(SESSIONS_HIGHWATER)   SESSIONS_HIGHWATER ,avg(SESSIONS_MAX) SESSIONS_MAX , avg(SESSIONS_CURRENT) SESSIONS_CURRENT
	FROM gv$license;
prompt  


-- SCHEMAS E TAMANHOS 
prompt SCHEMAS E TAMANHOS
col owner for a30 
select owner, round(sum(bytes)/1024/1024/1024,2) as tamanho_GB 
	from dba_segments 
	group by owner 
	order by 2;
prompt


-- TABLESPACES 
prompt TABLESPACES 
select tablespace_name from dba_tablespaces; 

SELECT
	d.tablespace_name,
	d.status,
	d.contents PTYPE,
	d.extent_management EXTENT_MGMT,
	round(NVL(sum(df.bytes) / 1024 / 1024, 0),2) SIZE_MB,
	round(NVL(sum(df.bytes) - NVL(sum(f.bytes), 0), 0)/1024/1024,0) USED_MB,
	round(NVL((sum(df.bytes) - NVL(sum(f.bytes), 0)) / sum(df.bytes) * 100, 0),0) USED_PERCENT,
	d.initial_extent,
	NVL(d.next_extent, 0) NEXT_EXTENT,
	round(NVL(max(f.bytes) / 1024 / 1024, 0),0) LARGEST_FREE 
FROM dba_tablespaces d
	,dba_data_files df
	,dba_free_space f 
WHERE d.tablespace_name = df.tablespace_name  
   AND df.tablespace_name = f.tablespace_name  (+) 
   AND df.file_id  = f.file_id  (+) 
GROUP BY d.tablespace_name, d.status, d.contents, d.extent_management
	  ,d.initial_extent, d.next_extent
 ORDER BY 1,2,3;
prompt 

-- compression

SELECT def_tab_compression, compress_for FROM   dba_tablespaces ;
SELECT count(1),compress_for FROM dba_tables where compression='ENABLED' group by compress_for ;
SELECT table_name, partition_name, compression, compress_for FROM dba_tab_partitions;

SELECT FILE_NAME, TO_CHAR(BYTES, '99999999999999999999') FROM DBA_DATA_FILES;


select owner, trunc(max(last_analyzed)) from dba_tables group by owner;


spool off;

-- OCUPACAO LOGICA POR PDB (exibe a quantia de objetos por tipo, e tamanho) 
-- APENAS A PARTIR DE ORACLE 12C
PROMPT PDBS

col PDB_NAME for a15 
select 
	p.pdb_name,
	s.segment_type,
	count(*),  
	round(sum(s.bytes)/1024/1024/1024,2) tam_gb,
	s.con_id 
from cdb_segments s,
	cdb_pdbs p
where p.con_id=s.con_id
group by p.pdb_name, s.con_id, s.segment_type 
order by 1,3; 
prompt 

-- AUXILIAR: DB_CACHE_SIZE 
prompt auxiliar: db_cache_size

COLUMN size_for_estimate          FORMAT 999999999999 heading'Cache Size (MB)'
COLUMN buffers_for_estimate       FORMAT 999999999 heading'Buffers'
COLUMN estd_physical_read_factor  FORMAT 999.90 heading'Estd Phys|Read Factor'
COLUMN estd_physical_reads        FORMAT 999,999,999,999,999 heading'Estd Phys| Reads'   

SELECT size_for_estimate, buffers_for_estimate, estd_physical_read_factor, estd_physical_reads
FROM V$DB_CACHE_ADVICE
WHERE name          ='DEFAULT'
AND block_size    = (SELECT value FROM V$PARAMETER WHERE name ='db_block_size')
AND advice_status ='ON';


prompt
prompt
prompt (script discovery versao LBY20220714)
spo off 