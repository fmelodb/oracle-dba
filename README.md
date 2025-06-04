# Oracle DBA Scripts

This repository contains scripts for DBA operations on Oracle database. The following code is mine and not from Oracle Corporation. This is for testing and learning purposes only, use it in production at your own risk.


## Exadata
- <B>Create ACFS FS on Exadata</B>: procedure to create acfs filesystem in Exadata / ExaDB-D
- <B>ExaDB-S Manual Backup using dbaascli </B>: procedure to perform manual backup using dbaascli

## Parsing Demo
- Compile .java programs and run them directly, without passing parameters. You need ojdbc8.jar to access an Oracle database [you can change the lib to another one to access any other database technology].
- It works with any version of Java.

## RAT
- <B>Run SPA</B>: it compares performance of SQLs on source and target
- <B>Run DB Replay</B>:it compares performance of workloads on source and target

## Resource Manager
- <B>Limit Parallel Queries</B>: it is a sample code to limit the amount of parallel sessions per SQL statement. The script creates 3 groups (high, medium, low) and assigns a limit to each. It is then mapped to a user in the database.

## Sharding
- <B>Sharding using System-Managed method</B>: procedure to create a system-based method sharding using BaseDB Service.

## TrueCache
- <B>Configuring TrueCache instance</B>: procedure to install and configure a single TrueCache on BaseDB Service.



