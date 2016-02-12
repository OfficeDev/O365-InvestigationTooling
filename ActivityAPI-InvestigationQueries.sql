-- Tell me everything that happened with this user
select * from auditaad where auditaad.UserId = "user@TENANTDOMAIN.onmicrosoft.com" order by CreationTime;
select * from auditexchange where auditexchange.UserId = "user@TENANTDOMAIN.onmicrosoft.com" order by CreationTime;
select * from auditsharepoint where auditsharepoint.UserId = "user@TENANTDOMAIN.onmicrosoft.com" order by CreationTime;

select * from auditaad order by CreationTime;
select * from auditexchange order by CreationTime;
select * from auditsharepoint order by CreationTime;

-- Tell me everything that happened from this IP
select * from auditaad where auditaad.ClientIP = "127.0.0.1" order by CreationTime;

-- Tell me everything that happened to this document
select * from auditsharepoint where auditsharepoint.SourceFileName = "FILENAME.JPG" order by CreationTime;

-- Tell me everything that happened bewteen 14Oct15 and 16Oct15 on AAD
select * from auditaad where CreationTime between "2015-10-17" and "2015-10-19" order by CreationTime;
