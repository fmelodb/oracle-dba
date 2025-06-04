import java.sql.*;
import java.io.*;
import java.util.*;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.Logger;

import oracle.jdbc.driver.OracleLog;
import oracle.jdbc.pool.OracleDataSource;

public class TrueCache2Connections {
  static String url_primary   = "jdbc:oracle:thin:@demodb.dbvcn.oraclevcn.com:1521/sales.dbvcn.oraclevcn.com";
  static String url_truecache = "jdbc:oracle:thin:@truecache1.dbvcn.oraclevcn.com:1521/sales_tc.dbvcn.oraclevcn.com";
  static String user = "[user]";
  static String password = "[pass]";

  public static void main(String args[]) {
    try {
        TrueCache2Connections t = new TrueCache2Connections();
      if(args != null && args.length >0 ) {
        url_primary = args[0];
        user = args[1];
        password = args[2];
      }
      t.test1();
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

  public void test1() throws SQLException {
    show("Basic test to connect to primary and True Cache in different connections");
    try {
      show("Get Connection from primary db");
      OracleDataSource ods1 = new OracleDataSource();
      show("URL = " + url_primary);
      ods1.setURL(url_primary);
      ods1.setUser(user);
      ods1.setPassword(password);
      Connection conn1 = ods1.getConnection();
      verifyConnection(conn1);  
      conn1.close();
      
      show("Get Connection from true cache instance 1");
      OracleDataSource ods2 = new OracleDataSource();
      show("URL = " + url_truecache);
      ods2.setURL(url_truecache);
      ods2.setUser(user);
      ods2.setPassword(password);
      Connection conn2 = ods2.getConnection();      
      verifyConnection(conn2); 
      conn2.close();

    } catch (SQLException sqex) {
      show("test1 -- failed" + sqex.getMessage()+":"+sqex.getCause());
      sqex.printStackTrace();
    }
    show("The end");
  }

  public void verifyConnection(Connection conn) {
    try {
      Statement statement = conn.createStatement();
      ResultSet rs = statement.executeQuery("SELECT database_role from v$database");
      ResultSetMetaData rsmd = rs.getMetaData();
      int columnsNumber = rsmd.getColumnCount();
      rs.next();
      show("Database role : " + rs.getString(1));
      rs.close();
      ResultSet resultSet = statement.executeQuery("SELECT SYS_CONTEXT('userenv', 'instance_name') as instance_name"
          + ", SYS_CONTEXT('userenv', 'server_host')" + " as server_host" + ", SYS_CONTEXT('userenv', 'service_name')"
          + " as service_name" + ", SYS_CONTEXT('USERENV','db_unique_name')" + " as db_unique_name" + " from sys.dual");
      resultSet.next();
      show("instance_name : " + resultSet.getString("instance_name"));
      show("server_host : " + resultSet.getString("server_host"));
      show("service_name : " + resultSet.getString("service_name"));
      show("db_unique_name : " + resultSet.getString("db_unique_name"));
      resultSet.close();
      statement.close();
    } catch (SQLException sqex) {
      show("verifyConnection failed " + sqex.getMessage());
    }
  }

  public void show(String msg) {
    System.out.println(msg);
  }
}

