"""Database utility functions for analytics ETL."""

import logging
import time
import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
from typing import List, Dict, Any, Optional
from config import DATABASE_URL, MAX_RETRIES, RETRY_DELAY

logger = logging.getLogger(__name__)


@contextmanager
def get_db_connection():
    """Get database connection with automatic cleanup."""
    conn = None
    try:
        conn = psycopg2.connect(DATABASE_URL)
        yield conn
        conn.commit()
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f"Database error: {e}")
        raise
    finally:
        if conn:
            conn.close()


def execute_query(
    query: str, 
    params: Optional[tuple] = None,
    fetch: bool = True,
    retry: bool = True
) -> Optional[List[Dict[str, Any]]]:
    """
    Execute a database query with optional retry logic.
    
    Args:
        query: SQL query to execute
        params: Query parameters
        fetch: Whether to fetch results
        retry: Whether to retry on failure
        
    Returns:
        Query results as list of dicts, or None if fetch=False
    """
    retries = MAX_RETRIES if retry else 1
    last_error = None
    
    for attempt in range(retries):
        try:
            with get_db_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute(query, params)
                    if fetch:
                        results = cur.fetchall()
                        return [dict(row) for row in results]
                    return None
        except Exception as e:
            last_error = e
            logger.warning(f"Query attempt {attempt + 1}/{retries} failed: {e}")
            if attempt < retries - 1:
                time.sleep(RETRY_DELAY)
            continue
    
    logger.error(f"Query failed after {retries} attempts: {last_error}")
    raise last_error


def call_rpc_function(
    function_name: str,
    params: Optional[Dict[str, Any]] = None
) -> Optional[Any]:
    """
    Call a Supabase RPC function.
    
    Args:
        function_name: Name of the RPC function
        params: Function parameters as dict
        
    Returns:
        Function result
    """
    param_placeholders = []
    param_values = []
    
    if params:
        for key, value in params.items():
            param_placeholders.append(f"{key} => %s")
            param_values.append(value)
    
    param_string = ", ".join(param_placeholders) if param_placeholders else ""
    query = f"SELECT * FROM {function_name}({param_string})"
    
    logger.info(f"Calling RPC function: {function_name}")
    return execute_query(query, tuple(param_values) if param_values else None)


def table_exists(table_name: str) -> bool:
    """Check if a table exists in the database."""
    query = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = %s
        );
    """
    result = execute_query(query, (table_name,))
    return result[0]['exists'] if result else False


def get_table_row_count(table_name: str) -> int:
    """Get the number of rows in a table."""
    query = f"SELECT COUNT(*) as count FROM {table_name};"
    result = execute_query(query)
    return result[0]['count'] if result else 0


def truncate_table(table_name: str):
    """Truncate a table (delete all rows)."""
    query = f"TRUNCATE TABLE {table_name} CASCADE;"
    logger.warning(f"Truncating table: {table_name}")
    execute_query(query, fetch=False)


def vacuum_analyze(table_name: Optional[str] = None):
    """Run VACUUM ANALYZE on a table or entire database."""
    if table_name:
        logger.info(f"Running VACUUM ANALYZE on {table_name}")
        query = f"VACUUM ANALYZE {table_name};"
    else:
        logger.info("Running VACUUM ANALYZE on database")
        query = "VACUUM ANALYZE;"
    
    # VACUUM cannot run inside a transaction
    conn = psycopg2.connect(DATABASE_URL)
    conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
    try:
        with conn.cursor() as cur:
            cur.execute(query)
    finally:
        conn.close()
