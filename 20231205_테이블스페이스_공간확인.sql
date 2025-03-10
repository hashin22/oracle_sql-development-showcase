SELECT 	TABLESPACE_NAME, 
		SUM(TOTAL) 			AS TOTAL,
		SUM(USED) 			AS USED,
		SUM(FREE) 			AS FREE,
		MAX(CASE WHEN A.TOTAL = 30 THEN 'NO' ELSE AUTOEXTENSIBLE END) AS AUTOEXTENSIBLE,
		
		SUM(FILE_CNT) 		AS FILE_CNT,
		SUM(CHK_CNT) 		AS CHK_CNT,
		SUM(CHK_TOT_BYTE) 	AS CHK_TOT_BYTE,
		SUM(CHK_USE_BYTE) 	AS CHK_FREEE_BYTE
FROM 	(
			SELECT 	A.TABLESPACE_NAME, 
					A.FILE_ID,
					ROUND(SUM(A.TOTAL)) 				AS TOTAL,
					ROUND((SUM(A.USED) - SUM(A.FREE))) 	AS USED,
					ROUND(SUM(A.FREE)) 					AS FREE,
					
					B.AUTOEXTENSIBLE,
			
					COUNT(DISTINCT A.FILE_ID) 																			AS FILE_CNT,		
					(SUM(A.TOTAL) - SUM(A.FREE))/SUM(A.TOTAL)*100 														AS RATE,
					(CASE WHEN (SUM(A.USED) - SUM(A.FREE))/SUM(A.TOTAL)*100 > 90 THEN 1 					ELSE 0 END)	AS CHK_CNT,
					(CASE WHEN (SUM(A.USED) - SUM(A.FREE))/SUM(A.TOTAL)*100 <= 90 THEN ROUND(SUM(A.USED)) 	ELSE 0 END)	AS CHK_TOT_BYTE,
					(CASE WHEN (SUM(A.USED) - SUM(A.FREE))/SUM(A.TOTAL)*100 <= 90 THEN ROUND(SUM(A.FREE)) 	ELSE 0 END)	AS CHK_USE_BYTE
					--SUM(1) AS CHK_CNT
					--SUM((CASE WHEN (SUM(TOTAL) - SUM(FREE))/SUM(TOTAL)*100 < 10 THEN 1 ELSE 0 END)) AS CHK_CNT
					
			FROM 	(
						SELECT 	TABLESPACE_NAME, FILE_ID,
								DECODE(A.AUTOEXTENSIBLE, 'YES', A.MAXBYTES,'NO', A.BYTES)/1024/1024/1024 AS TOTAL, 
								A.BYTES AS USED,
								0 			AS FREE		
						FROM 	DBA_DATA_FILES	A
						
						UNION ALL
						
						SELECT 	TABLESPACE_NAME,FILE_ID, 0 AS TOTAL, 0 AS USED, SUM(BYTES)/1024/1024/1024 AS BYTES
						FROM 	DBA_FREE_SPACE A
						GROUP BY TABLESPACE_NAME,FILE_ID
					)A
					
					INNER JOIN DBA_DATA_FILES B
					ON 		A.TABLESPACE_NAME 	= B.TABLESPACE_NAME
					AND		A.FILE_ID 			= B.FILE_ID
					
			GROUP BY 	A.TABLESPACE_NAME, A.FILE_ID, B.AUTOEXTENSIBLE
		) A
GROUP BY A.TABLESPACE_NAME

UNION ALL

SELECT 	A.TABLESPACE_NAME, 
		ROUND(SUM(A.BYTES_USED + A.BYTES_FREE) / 1048576 / 1024), 
		ROUND(SUM(B.BYTES_USED) / 1048576 / 1024), 
		ROUND(SUM(A.BYTES_USED + A.BYTES_FREE - B.BYTES_USED) / 1048576 / 1024), 
		'NO' 																																							AS AUTOEXTENSIBLE,
		
		COUNT(*) 																																						AS FILE_CNT,
		SUM(CASE WHEN B.BYTES_USED / (A.BYTES_USED+A.BYTES_FREE) * 100 > 90 THEN 1 																		ELSE 0 END) 	AS CHK_CNT,
		SUM(CASE WHEN B.BYTES_USED / (A.BYTES_USED+A.BYTES_FREE) * 100 < 90 THEN ROUND((A.BYTES_USED+A.BYTES_FREE) / 1024 / 1024 / 1024)				ELSE 0 END) 	AS CHK_TOT_BYTE,
		SUM(CASE WHEN B.BYTES_USED / (A.BYTES_USED+A.BYTES_FREE) * 100 < 90 THEN ROUND((A.BYTES_USED+A.BYTES_FREE - B.BYTES_USED) / 1024 / 1024 / 1024)	ELSE 0 END) 	AS CHK_FREE_BYTE
		--ROUND((SUM(BYTES_FREE) / SUM(BYTES_USED + BYTES_FREE)) * 100,2) FREE_RATE, 
		--100 - ROUND((SUM(BYTES_FREE) / SUM(BYTES_USED + BYTES_FREE)) * 100,2) USED_RATE, 
		--ROUND(MAX(BYTES_USED + BYTES_FREE) / 1048576 / 1024, 2) 
FROM 	SYS.V_$TEMP_SPACE_HEADER A

		LEFT OUTER JOIN v$temp_extent_pool B
		ON 		A.TABLESPACE_NAME 	= B.TABLESPACE_NAME
		AND		A.FILE_ID 			= B.FILE_ID
		
GROUP BY A.TABLESPACE_NAME
ORDER BY TABLESPACE_NAME;
	