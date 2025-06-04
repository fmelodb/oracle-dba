DECLARE
    db_params dbms_service.svc_parameter_array;
BEGIN
   
   DBMS_SERVICE.CREATE_SERVICE('SALES_TC', 'SALES_TC', db_params); -- started on true cache server only

   db_params('true_cache_service') := 'SALES_TC';
   DBMS_SERVICE.CREATE_SERVICE('SALES', 'SALES', db_params); -- started on primary database server only

END;
/