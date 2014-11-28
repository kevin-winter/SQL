ALTER PROCEDURE [dbo].[sp_moveSP]
@v_includePKEs bit,
@v_fromScID varchar(42),
@v_toScID varchar(42)
AS
BEGIN
	DECLARE @v_fromSpID varchar(42) = (select ServicePackageID from ServiceConfiguration where RecID = @v_fromScID)
	DECLARE @v_toSpID varchar(42) = (select ServicePackageID from ServiceConfiguration where RecID = @v_toScID)
	DECLARE @vi_man bit = (select top 1 ManualAssigned from ServiceAssignment where ServicePackageID = @v_fromSpID 
							and ISNULL(ProductCatalogItemID,'') = '' and Assigned = 1)
	
	PRINT 'Transfer Assignments'
	update ServiceAssignment set Assigned = 1, 
								ManualAssigned = case when (@vi_man=1) then 1 else 0 end, 
								ManualAssignedDateTime = case when (@vi_man=1) then GETDATE() else null end
	where ServicePackageID = @v_toSpID 
	and ISNULL(ProductCatalogItemID,'') = ''
	and CustomerID in (	select customerid from ServiceAssignment 
						where ServicePackageID = @v_fromSpID 
						and ISNULL(ProductCatalogItemID,'') = ''
						and Assigned = 1)
						
	update ServiceAssignment set Assigned = 0
	where ServicePackageID = @v_fromSpID 
	and ISNULL(ProductCatalogItemID,'') = ''
	and Assigned = 1
	
	PRINT 'Retire old SP'
	update ServiceObject set Status = 'Retired', Stage = 'Retired'
	where RecID = @v_fromSpID
	insert into Journal (RecID, JournalTypeID, JournalTypeName, CreatedDateTime, CreatedBy, ParentRecordID, Details, ShowInSelfService)
	values (NEWID(), '934d80e020e2eb4359e59c47168f69db78f7fd9541', 'History', GETDATE(), 'SP-Mover',@v_fromSpID, 'This Service Package was replaced by ' + (select name from ServiceObject where RecID = @v_toSpID),0)

	insert into Journal (RecID, JournalTypeID, JournalTypeName, CreatedDateTime, CreatedBy, ParentRecordID, Details, ShowInSelfService)
	values (NEWID(), '934d80e020e2eb4359e59c47168f69db78f7fd9541', 'History', GETDATE(), 'SP-Mover',@v_toSpID, 'This Service Package replaces ' + (select name from ServiceObject where RecID = @v_fromSpID),0)
	
	PRINT 'Transfer PKEs'
	IF (@v_includePKEs = 1)
	BEGIN
		DECLARE @sql varchar(max)
		select @sql =  coalesce(@sql + ' ', '') + 'exec sp_movePKE @v_pkeID='''+childid+''', @v_spID='''+ @v_toSpID
		+''', @v_optional='+ CASE WHEN (JoinReason = 'Optional Product') THEN '1' ELSE '0' END 
		from ProductItemJoinTable where ParentID = @v_fromSpID
		exec(@sql)
	END
END