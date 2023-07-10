/*
        An example Java program that showcases the subconnection concept to read and write data from and into the Exasol server.

        Originally mentioned in article https://exasol.my.site.com/s/article/Parallel-connections-with-JDBC
*/

package com.exasol.jdbc.tests;

import java.math.BigDecimal;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Time;
import java.sql.Timestamp;
import java.util.Arrays;
import java.util.Calendar;

import com.exasol.jdbc.EXAConnection;
import com.exasol.jdbc.EXAPreparedStatement;
import com.exasol.jdbc.EXAResultSet;


public class ParallelConnectionsExample {

    static String connectStr=null;
    public static int numPackagesPerNode = 10;
    /** Prepared statement parameters must be sent in packages if there is much data to be send.
     * Recommended data size in one package is around 2MB. The user must estimate by his own how many rows this
     * will be. It depends on the structure of the table and the real size of the data to send. 
     */ 
    public static int numRowsPerPackage = 1000;
    public static int numRowsPerNode=0; 
    public static boolean printOutput=true;
    public static String logging=""; 
    public static Date curDate=new Date(Calendar.getInstance().getTimeInMillis());
    public static Timestamp curTimestamp=new Timestamp(Calendar.getInstance().getTimeInMillis());
    
    
    public ParallelConnectionsExample() {
    }
    
    /** main(String[] args)
     * @param args args[0]=connection string (host:port). Optional arguments: for parallel prepared 
     * inserts: args[1]=numPackagesPerNode, args[2]=numRowsPerPackage, args[3]=logdir
     * Use logging only for debugging, it may slow down your application.
     */
    public static void main(String[] args) {
        connectStr=args[0];
        if (args.length>1) numPackagesPerNode=Integer.valueOf(args[1]);
        if (args.length>2) numRowsPerPackage=Integer.valueOf(args[2]);
        numRowsPerNode=numPackagesPerNode*numRowsPerPackage;
        if (args.length>3) logging+=";debug=1;logdir=" + args[3];
        try {
            new ParallelConnectionsExample().StartParallelConnections();
        } catch (Exception e) {
            e.printStackTrace();
        }
        if (printOutput) System.out.println("Done.");
    }
    
    /** This function is used to start the test automatically in the EXASOL Test System
     * 
     * @param cs connectString
     * @param np numPackagesPerNode
     * @param nr numRowsPerPackage
     * @param p if false there will be no console output
     * @return 
     * @throws Exception
     */
    public int StartParallelConnections(String cs, int np, int nr, boolean p) throws Exception 
    {
        connectStr=cs;
        numPackagesPerNode=np;
        numRowsPerPackage=nr;
        printOutput=p;
        return StartParallelConnections();
    }

    /** Starts the 3 tests: 1. Insert rows parallel. 2. Read rows after executing the select statement 
     * on each node. 3. Read rows using a handle from the main connection. 
     * @return
     * @throws Exception
     */
    public int StartParallelConnections() throws Exception 
    {
        String connStr="jdbc:exa:" + connectStr + ";autocommit=0;encryption=1" + logging;
        EXAConnection connection = null;
        try {
            Class.forName("com.exasol.jdbc.EXADriver");
            connection = (EXAConnection)DriverManager.getConnection(connStr, "sys", "exasol");
        } catch (SQLException sqlex) {
            throw sqlex;
        } catch (ClassNotFoundException cnfe) {
            throw cnfe;
        }
        Statement stmt=connection.createStatement();
        try {
            stmt.execute("create schema test");
        } catch (SQLException ex) { } 
        stmt.execute("create or replace table test.tep(i int, c varchar(128))");
        connection.commit();
        
        /** In this example we ask the server to accept up to 20 connections. For each node there will be 
         * a host and a port in the main connection object. If you have 5 machines in your cluster
         * and ask for 20 connections, only 5 will be available. */
        int nSlaves=connection.EnterParallel(20);
        if (printOutput) System.out.println(" Main Node - nSlaves=" + nSlaves);
        if (printOutput) System.out.println(new Time(Calendar.getInstance().getTimeInMillis()));
        
        ParallelConnectionThread [] slaveThreads;
        
        /** A prepared statement (insert) runs parallel on all connections. */
        if (printOutput) System.out.println(" - INSERT ROWS PARALLEL - ");
        slaveThreads=new ParallelInsertThread[nSlaves];
        StartThreads(slaveThreads, nSlaves, connection, 0);
        connection.commit();
        if (printOutput) System.out.println(new Time(Calendar.getInstance().getTimeInMillis()));
        
        /** Select runs on all parallel connections, partial results are retrieved for each connection. */
        if (printOutput) System.out.println(" - READ ROWS PARALLEL - ");
        slaveThreads=new ParallelSelectThread[nSlaves];
        StartThreads(slaveThreads, nSlaves, connection, 0);
        if (printOutput) System.out.println(new Time(Calendar.getInstance().getTimeInMillis()));
        
        /** Creates a result set, then reads it on the parallel nodes using the result set handle. */
        if (printOutput) System.out.println(" - READ ROWS PARALLEL USING A HANDLE - ");
        EXAResultSet res=(EXAResultSet)stmt.executeQuery("select * from test.tep");
        slaveThreads=new ParallelSelectHandleThread[nSlaves];
        /** read the handle for all result parts */
        StartThreads(slaveThreads, nSlaves, connection, res.GetHandle());
        if (printOutput) System.out.println(new Time(Calendar.getInstance().getTimeInMillis()));

        /** Free resources in the server. */
        res.close();
        stmt.close();
        connection.close();
        
        return 0;
    }

    /** Utilit function used in this testcase to start the threads and wai for them to end
     * 
     * @param slaveThreads the treads that will start the slave connections
     * @param nSlaves number of threads/connections
     * @param connection main connection
     * @param handle statement handle used in just one of the tests to read the rows
     */
    private void StartThreads(ParallelConnectionThread [] slaveThreads, int nSlaves, EXAConnection connection, int handle)
    {
        for (int i=0; i<nSlaves; i++)
        {
            String [] hosts=connection.GetSlaveHosts();
            int [] ports=connection.GetSlavePorts();
            if (printOutput) System.out.println(" Main Node - Token: " + connection.GetSlaveToken() + " Host: " + hosts[i] + " Port: " + ports[i]);
            if (printOutput) System.out.println(" Main Node - Starting thread [" + i + "]");
            
            if (slaveThreads instanceof ParallelSelectThread [])
                slaveThreads[i]=new ParallelSelectThread(i, connection.GetSlaveToken(), hosts[i], ports[i]);
            else if (slaveThreads instanceof ParallelInsertThread [])
                slaveThreads[i]=new ParallelInsertThread(i, connection.GetSlaveToken(), hosts[i], ports[i]);
            else if (slaveThreads instanceof ParallelSelectHandleThread [])
                slaveThreads[i]=new ParallelSelectHandleThread(i, connection.GetSlaveToken(), hosts[i], ports[i], handle);
            
            slaveThreads[i].start();
        }
        for (int i=0; i<nSlaves; i++)
            try {
                slaveThreads[i].join();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        if (printOutput) System.out.println();
    }
    
    /** Defines our threads
     */
    class ParallelConnectionThread extends Thread {
        long token=0;
        String slaveHost=null;
        int slavePort=0;
        int slaveId=0;
    }
    
    /** Inserts rows on every slave connection. Every node prepares the same insert statement.
     */
    class ParallelInsertThread extends ParallelConnectionThread {
        
    ParallelInsertThread(int sid, long t, String sh, int sp) {
            slaveId=sid;
            token=t;
            slaveHost=sh;
            slavePort=sp;
        }

        public void run() {
            try {
                if (printOutput) System.out.println("ParallelInsertThread[" + slaveId + "] - Token: " + token + " Host: " + slaveHost + " Port: " + slavePort);
                String connStr="jdbc:exa-slave:" + slaveHost + ":" + slavePort + ";slavetoken=" + token + 
                        ";autocommit=0;encryption=1" + logging + ";slaveID=" + slaveId;
                EXAConnection connection;
                try {
                    connection = (EXAConnection)DriverManager.getConnection(connStr, "sys", "exasol");
                } catch (SQLException ex)
                {
                    throw ex;
                }
  
                PreparedStatement stmt=connection.prepareStatement("insert into test.tep values (?, ?)");
                if (slaveId==0) Thread.sleep(1000);
                
                /** Prepared statement parameters must be sent in packages if there is much data to be send.
                * Recommended data size in one package is around 2MB. */
                long rowCounter=0;
                //final int col2precision=128;
                for(int j=0; j<numPackagesPerNode; j++)
                {
                    for (int i=0; i<numRowsPerPackage; i++)
                    {          
                        if (rowCounter % 7 == 0) stmt.setNull(1, java.sql.Types.INTEGER);
                        else stmt.setInt(1, (int)((i + j*numRowsPerPackage + numRowsPerNode*slaveId) % Integer.MAX_VALUE));
                        
                        /** If the value will be set using setString always use setNull(VARCHAR) here. */
                        if (rowCounter % 9 == 0) stmt.setNull(2, java.sql.Types.VARCHAR);  
                        else stmt.setString(2, new String(new char[(int)rowCounter % 8]).replace("\0", " abc " + i));
                        
                        stmt.addBatch();
                        rowCounter++;
                    }
                    
                    /** You can set the maximal precision for varchar columns here if you know it and if you have to. 
                     * In parallel connections the data types, including precision and scale attributes, are not allowed 
                     * to change for one PreparedStatement between executeBatch()'es. The setPrecision() method is offered 
                     * as a fall back if for some reasons the server cannot guess the right precision for some strings he 
                     * expects and you have to set it manually.
                     * Also you can use setMaxScale() if you want to use setBigDecima() to set the maximal scale of your 
                     * parameter column data, Anyway, most users send decimal parameter as string so they don't have to 
                     * care about the scale.
                     */
                    //((EXAPreparedStatement)stmt).setMaxVarcharLen(2, col2precision);
                    
                    stmt.executeBatch();
                    if (printOutput) System.out.println("ParallelInsertThread[" + slaveId + "] - package[" + j + "] done");
                }
                stmt.close();
                connection.close();
                if (printOutput) System.out.println("ParallelInsertThread[" + slaveId + "] - did send " + rowCounter + " rows");
                if (printOutput) System.out.println("ParallelInsertThread[" + slaveId + "] - closed");
            } catch (Exception ex) {
                if (printOutput) System.out.println("ParallelInsertThread[" + slaveId + "] - Unexpected exception: " + ex.toString());
                ex.printStackTrace();
            }
        }
    }
    
    /** Reads rows after a select statement run on every parallel connection simultaneously. 
     * The statement must be exactly the same on all nodes.
     */
    class ParallelSelectThread extends ParallelConnectionThread {
        
        ParallelSelectThread(int sid, long t, String sh, int sp) {
            slaveId=sid;
            token=t;
            slaveHost=sh;
            slavePort=sp;
        }

        public void run() {
            try {
                if (printOutput) System.out.println("ParallelSelectThread[" + slaveId + "] - Token: " + token + " Host: " + slaveHost + " Port: " + slavePort);
                /** New connection string parameters: 
                 * In addition to the URL's jdbc:exa and jdbc:exa-debug we have added for the parallel connections the URL jdbc:exa-slave .
                 * You also have to specify slavetoken= , this is a long integer used to identify the connection group members.
                 * The parameter slaveId is optional and does nothing. It can be seen in log files to help debugging.  
                 */
                String connStr="jdbc:exa-slave:" + slaveHost + ":" + slavePort + ";slavetoken=" + token + 
                        ";autocommit=0;encryption=1" + logging + ";slaveID=" + slaveId;
                EXAConnection connection;
                try {
                    connection = (EXAConnection)DriverManager.getConnection(connStr, "sys", "exasol");
                } catch (SQLException ex)
                {
                    throw ex;
                }
                Statement stmt=connection.createStatement();
                ResultSet res=stmt.executeQuery("select * from test.tep");
                long rowCounter=0;
                while (res.next())
                {
                    /*if (printOutput) System.out.print("ParallelSelectHandleThread[" + slaveId + "] - ");
                    for (int i=1; i<=resmd.getColumnCount(); i++)
                    {
                        String val=res.getString(i) + " ";
                        if (res.wasNull()) val="NULL ";
                        if (printOutput) System.out.print(val);
                    }
                    if (printOutput) System.out.println();*/
                    rowCounter++;
                }
                //Free resources in the server.
                res.close();
                stmt.close();
                connection.close();
                if (printOutput) System.out.println("ParallelSelectThread[" + slaveId + "] - did read " + rowCounter + " rows");
                if (printOutput) System.out.println("ParallelSelectThread[" + slaveId + "] - closed");
            } catch (Exception ex) {
                if (printOutput) System.out.println("ParallelSelectThread[" + slaveId + "] - Unexpected exception: " + ex.toString());
                ex.printStackTrace();
            }
        }
    }
    
    /** Reads rows on every connection using a handle from the main connection.
     * The select was executed on the main connection to generate the handle.
     */
    class ParallelSelectHandleThread extends ParallelConnectionThread {
        private int handle=0; 
        
        ParallelSelectHandleThread(int sid, long t, String sh, int sp, int h) {
            slaveId=sid;
            token=t;
            slaveHost=sh;
            slavePort=sp;
            handle=h;
        }

        public void run() {
            try {
                if (printOutput) System.out.println("ParallelSelectHandleThread[" + slaveId + "] - Token: " + token + " Host: " + slaveHost + " Port: " + slavePort);
                String connStr="jdbc:exa-slave:" + slaveHost + ":" + slavePort + ";slavetoken=" + token + 
                        ";autocommit=0;encryption=1" + logging + ";slaveID=" + slaveId;
                EXAConnection connection;
                try {
                    connection = (EXAConnection)DriverManager.getConnection(connStr, "sys", "exasol");
                } catch (SQLException ex)
                {
                    throw ex;
                }
                /** DescribeResult will return the partial result for this parallel connection for the result handle 
                 * obtained from the main connection.
                 */
                ResultSet res=connection.DescribeResult(handle);
                ResultSetMetaData resmd = res.getMetaData();
                long rowCounter=0;
                while (res.next())
                {
                    /*if (printOutput) System.out.print("ParallelSelectHandleThread[" + slaveId + "] - ");
                    for (int i=1; i<=resmd.getColumnCount(); i++)
                    {
                        String val=res.getString(i) + " ";
                        if (res.wasNull()) val="NULL ";
                        if (printOutput) System.out.print(val);
                    }
                    if (printOutput) System.out.println();*/
                    rowCounter++;
                }
                //Free resources in the server.
                res.close();
                connection.close();
                if (printOutput) System.out.println("ParallelSelectHandleThread[" + slaveId + "] - did read " + rowCounter + " rows");
                if (printOutput) System.out.println("ParallelSelectHandleThread[" + slaveId + "] - closed");
            } catch (Exception ex) {
                if (printOutput) System.out.println("ParallelSelectHandleThread[" + slaveId + "] - Unexpected exception: " + ex.toString());
                ex.printStackTrace();
            }
        }
    }
    
}

