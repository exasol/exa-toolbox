/*
        The query to obtain information about read and write locks held by open sessions.
        This script applies for Exasol Database versions starting from 7.1.

        Originally mentioned in article https://exasol.my.site.com/s/article/How-to-determine-idle-sessions-with-open-transactions-Except-Snapshot-Executions?language=en_US
*/

with
	EXA_SQL as (
		select
			SESSION_ID,
			STMT_ID,
			COMMAND_CLASS,
			COMMAND_NAME,
			SNAPSHOT_MODE
		from
			--EXA_DBA_AUDIT_SQL                   -- delivers more exact results (if available)
			EXA_SQL_LAST_DAY
		where
			SESSION_ID in (select SESSION_ID from EXA_DBA_SESSIONS)
			and success
	),
	SESSION_RISKS as (
		select
			SESSION_ID,
			HAS_LOCKS
		from
			(
				select
					SESSION_ID,
					decode(
						greatest(CURRENT_ACCESS, LAST_ACCESS),
						0,
						'NONE',
						1,
						'READ LOCKS',
						2,
						'WRITE LOCKS'
					) HAS_LOCKS
				from
					(
						select
							S.SESSION_ID,
							case
								when
									(S.STATUS not in ('IDLE', 'DISCONNECTED')) OR
									(
										S.COMMAND_NAME not in ('COMMIT', 'ROLLBACK', 'NOT SPECIFIED')
									)
								then
									case
										when
											S.COMMAND_NAME in (
												'SELECT', 'DESCRIBE', 'OPEN SCHEMA', 'CLOSE SCHEMA', 'FLUSH STATISTICS', 'EXECUTE SCRIPT'
											)
										then
											1
										else
											2
									end
								else
									0
							end CURRENT_ACCESS,
							zeroifnull(A.ACCESS) LAST_ACCESS
						from
								EXA_DBA_SESSIONS S
							left join
								(
									select
										SESSION_ID,
										max(ACCESS) ACCESS
									FROM
										(
											select
												SESSION_ID,
												case
													when
														(
															COMMAND_NAME not in ('COMMIT', 'ROLLBACK', 'NOT SPECIFIED')
															and SNAPSHOT_MODE <> 'ON'
														)
													then
														case
															when
																COMMAND_NAME in (
																	'SELECT',
																	'DESCRIBE',
																	'OPEN SCHEMA',
																	'CLOSE SCHEMA',
																	'FLUSH STATISTICS',
																	'EXECUTE SCRIPT'
																)
															then
																1
															else
																2
														end
													else
														0
												end ACCESS
											from
												EXA_SQL C
											where
												C.COMMAND_CLASS <> 'TRANSACTION' and
												not exists(
													select
														*
													from
														EXA_SQL E
													where
														E.SESSION_ID = C.SESSION_ID and
														E.STMT_ID > C.STMT_ID and
														E.COMMAND_CLASS = 'TRANSACTION'
												)
										)
									group by
										SESSION_ID
								) A
							on
								S.SESSION_ID = A.SESSION_ID
					)
				where
					SESSION_ID <> 4
			)
	)
select
	HAS_LOCKS,
	case
		when
			DURATION > '1:00:00' and
			STATUS = 'IDLE'
		then
			decode(
				HAS_LOCKS,
				'READ LOCKS',
				'CRITICAL',
				'WRITE LOCKS',
				'VERY CRITICAL',
				NULL
			)
	end EVALUATION,
	S.*
from
		EXA_DBA_SESSIONS S
	left join
		SESSION_RISKS R
	on
		(S.SESSION_ID = R.SESSION_ID)
order by
	EVALUATION desc,
	LOGIN_TIME;