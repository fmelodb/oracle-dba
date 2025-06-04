
-- Connect to privileged user on PDB.
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER = pdb1;

-- Create a resource plan.
BEGIN
  DBMS_RESOURCE_MANAGER.clear_pending_area();
  DBMS_RESOURCE_MANAGER.create_pending_area();

  -- Create plan
  DBMS_RESOURCE_MANAGER.create_plan(
    plan => 'dw_plan', comment => 'An example plan for managing parallel statements');

  -- Create consumer groups
  DBMS_RESOURCE_MANAGER.create_consumer_group(
    consumer_group => 'high', comment => 'high priority');

  DBMS_RESOURCE_MANAGER.create_consumer_group(
    consumer_group => 'medium', comment => 'medium priority');
	
  DBMS_RESOURCE_MANAGER.create_consumer_group(
    consumer_group => 'low', comment => 'low priority');

  -- Assign consumer groups to plan and define priorities
  DBMS_RESOURCE_MANAGER.create_plan_directive (
    plan                     => 'dw_plan',
    group_or_subplan         => 'high',
	PARALLEL_DEGREE_LIMIT_P1 => 16); -- max parallel 16

  DBMS_RESOURCE_MANAGER.create_plan_directive (
    plan                     => 'dw_plan',
    group_or_subplan         => 'medium',
	PARALLEL_DEGREE_LIMIT_P1 => 8);  -- max parallel 8
	
  DBMS_RESOURCE_MANAGER.create_plan_directive (
    plan                     => 'dw_plan',
    group_or_subplan         => 'low',
	PARALLEL_DEGREE_LIMIT_P1 => 1);  -- max parallel 1

  DBMS_RESOURCE_MANAGER.create_plan_directive(
    plan                     => 'dw_plan',
    group_or_subplan         => 'OTHER_GROUPS',
    PARALLEL_DEGREE_LIMIT_P1 => 4);  -- max parallel 4

  DBMS_RESOURCE_MANAGER.validate_pending_area;
  DBMS_RESOURCE_MANAGER.submit_pending_area();
END;
/

-- Assign an user to a consumer group (fmelo user to high consumer group, for example)
BEGIN
  DBMS_RESOURCE_MANAGER.clear_pending_area();
  DBMS_RESOURCE_MANAGER.create_pending_area();
  
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP(grantee_name => 'FMELO', consumer_group => 'high',   grant_option => FALSE);
  
  DBMS_RESOURCE_MANAGER.SET_CONSUMER_GROUP_MAPPING(DBMS_RESOURCE_MANAGER.ORACLE_USER, 'FMELO', 'high');
  DBMS_RESOURCE_MANAGER.SET_INITIAL_CONSUMER_GROUP('FMELO', 'high');
  
  DBMS_RESOURCE_MANAGER.validate_pending_area;
  DBMS_RESOURCE_MANAGER.submit_pending_area();
END;
/

ALTER SYSTEM SET RESOURCE_MANAGER_PLAN = dw_plan;

