--seperator
select * from ServiceConfiguration s 
join ProductCatalogItem p on p.RecID = s.ProductCatalogItemID 
where ((description not like 'lh%'
and description not like 'tc%')
or Description is null)
and s.RecID = '93d5ca0f6bee021ae937da43408d632ea7051c703b'
--0 = menu, 1 != menu

--mit menu
DECLARE @menu varchar(20) = (select description from ProductCatalogItem where RecID = (select ProductCatalogItemID from ServiceConfiguration where RecID = ''))

insert into Baan
select a.sam,a.FullName,a.pke,a.Description, b.menu,b.login, b.fullname
from(select c.SAMAccountName as sam,s.name,s.FullName as pke, p.Description, c.FullName as fullname
	from ServiceAssignment s
	join Customer c on s.CustomerID = c.RecID
	join ProductCatalogItem p on p.RecID = s.ProductCatalogItemID
	join ServiceObject sp on sp.RecID = s.ServicePackageID
	where s.Assigned = 1) a
full outer join
	(SELECT t.[Login] as login ,[StartupMenuPackage]+[StartupMenuModule]+[StartupMenuCode] as menu, t.name as fullname
	FROM [LBHSV027].[Baan].[dbo].[tb_TritonUser] t
	join lbhsv027.baan.dbo.tb_unixuser u
	on t.login = u.login 
	where status = 'aktiv'
	and company = '211'
	) b
on a.Description = b.menu collate SQL_Latin1_General_CP1_CI_AS 
and a.sam  = b.[login] collate SQL_Latin1_General_CP1_CI_AS 
where (a.Description = @menu AND b.menu is null)
or (b.menu = @menu and a.Description is null)
order by sam

--ohne menu
select a.sam,a.FullName,a.pke,a.Description, null,b.login, b.fullname
from(select c.SAMAccountName as sam,s.name,s.FullName as pke, p.Description, c.FullName as fullname
	from ServiceAssignment s
	join Customer c on s.CustomerID = c.RecID
	join ProductCatalogItem p on p.RecID = s.ProductCatalogItemID
	where s.Assigned = 1
	and s.fullname like '%P-Recht%LBH%') a
full outer join
(SELECT  t.[Login] as login, t.name as fullname, t.pberechtigung
FROM [LBHSV027].[Baan].[dbo].[tb_TritonUser] t
join lbhsv027.baan.dbo.tb_unixuser u
on t.login = u.login 
where status = 'aktiv'
and company = '211'
and t.pberechtigung = 1
--shellberechtigung = 2
--usertyp = 1 --superuser
) b
on a.sam = b.login collate SQL_Latin1_General_CP1_CI_AS
where b.login is null
or a.sam is null