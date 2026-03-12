-- Run this in Supabase → SQL Editor
-- Creates a function that the web survey uses to look up the candidate name by token

CREATE OR REPLACE FUNCTION get_candidate_info_by_token(p_token text)
RETURNS TABLE(link_id text, session_id text, candidate_name text)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    fl.id::text          AS link_id,
    fl.session_id::text  AS session_id,
    u.full_name          AS candidate_name
  FROM  feedback_links fl
  JOIN  assessment_sessions s ON s.id = fl.session_id
  JOIN  users u               ON u.id = s.candidate_id
  WHERE fl.token = p_token
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_candidate_info_by_token TO anon;
