--
-- Define SQL tables for session management code
--
-- $Id: session-create.sql,v 1.1 2004/01/05 21:08:26 karl Exp $
--
--

create table rivet_session(
    ip_address		inet,
    session_start_time	timestamp,
    session_update_time	timestamp,
    session_id		varchar,

    UNIQUE( session_id )
);

create table rivet_session_cache(
    session_id		varchar REFERENCES rivet_session(session_id) ON DELETE CASCADE,
    package		varchar,
    key                 varchar,
    data                varchar,

    UNIQUE( session_id, package, key )
);
create index rivet_session_cache_idx ON rivet_session_cache( session_id );

