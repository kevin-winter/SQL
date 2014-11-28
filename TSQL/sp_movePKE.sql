ALTER PROCEDURE [dbo].[sp_movePKE]
@v_pkeID varchar(42), --v_pke
@v_spID varchar(42), --v_sp
@v_optional bit
AS
BEGIN
	SET NOCOUNT ON
	PRINT 'Start declaring'
	DECLARE @vi_pke varchar(42) = (select name from ProductCatalogItem where recid = @v_pkeID)
	DECLARE @vi_newPKEID varchar(42) = NEWID()
	DECLARE @vi_sp varchar(42) = (select name from ServiceObject where recid = @v_spID)
	DECLARE @vi_optional varchar(50) = (select CASE WHEN @v_optional = 1 THEN 'Optional Product' ELSE 'Integrated Product' END)
	DECLARE @col varchar(max)
	DECLARE @sql varchar(max)
	
	PRINT 'Check Constraints'
	IF ((select status from ProductCatalogItem where RecID = @v_pkeID) = 'Retired') RETURN

	IF (@vi_pke IS NULL OR @v_pkeID IS NULL)
		BEGIN
			RAISERROR ('The PKE %s does not exist!',-1,-1,@vi_PKE)
			RETURN
		END

	IF (@vi_sp IS NULL OR @v_spID IS NULL)
		BEGIN
			RAISERROR ('The SP %s does not exist!',-1,-1,@vi_SP)
			RETURN
		END

	IF (@v_optional IS NULL)
		BEGIN
			RAISERROR ('Please provide a Join Reason',-1,-1)
			RETURN
		END

	PRINT 'Create Copy of PKE'
	select @col = coalesce(@col + ', ', '')+ '[' + COLUMN_NAME + ']'
	from INFORMATION_SCHEMA.COLUMNS
	where TABLE_NAME = 'ProductCatalogItem'
	and COLUMN_NAME <> 'LastModTimeStamp'

	SET @sql = 'select '+@col+' into #PKEtemp from ProductCatalogItem where recid = '''+@v_PKEID+''';
	update #PKEtemp set RecID = '''+@vi_newPKEID+''', CreatedDateTime = GETDATE();
	insert into ProductCatalogItem  ('+@col+') select '+@col+' from #PKEtemp'
	EXEC(@sql)
	insert into Journal (RecID, JournalTypeID, JournalTypeName, CreatedDateTime, CreatedBy, ParentRecordID, Details, ShowInSelfService)
	values (NEWID(), '934d80e020e2eb4359e59c47168f69db78f7fd9541', 'History', GETDATE(), 'PKE-Mover',@vi_newPKEID, 'This ProductCatalogItem was created by the PKE-Mover',0)

	
	PRINT 'Link new PKE to SP'
	insert into ProductItemJoinTable (RecID, ParentID, ParentName, ParentType, ChildID, ChildName, ChildType, JoinReason)
	values ( NEWID(), @v_SPID, @vi_SP, '93a0668a5cc0595e73a3674c3590b8188b2502ace4',
					  @vi_newPKEID, @vi_PKE, '93965c895638e14d4bbae7470794cf2a82b0c0023d',
					  @vi_optional)
					  
	PRINT 'Create new Service Configuration based on old one'
	SET @col = NULL
	select @col = coalesce(@col + ', ', '')+ '[' + COLUMN_NAME + ']'
	from INFORMATION_SCHEMA.COLUMNS
	where TABLE_NAME = 'ServiceConfiguration'
	and COLUMN_NAME <> 'LastModTimeStamp'
	
	SET @sql = 'select '+@col+' into #SCtemp from ServiceConfiguration where ProductCatalogItemID = '''+@v_PKEID+''';
	update #SCtemp set RecID = NEWID(), CreatedDateTime = GETDATE(), ServicePackageID = '''+@v_SPID+''', 
					   BusinessServiceID = (select RelatedBusinessServiceID from ServiceObject where Name = '''+@vi_SP+'''),
					   ProductCatalogItemType = '''+ @vi_optional+''',
					   ProductCatalogItemID = '''+@vi_newPKEID+'''
	insert into ServiceConfiguration ('+@col+') select '+@col+' from #SCtemp'
	EXEC(@sql)

	PRINT 'Retire old PKE'
	update ProductCatalogItem set Status = 'Retired' where RecID = @v_PKEID
	insert into Journal (RecID, JournalTypeID, JournalTypeName, CreatedDateTime, CreatedBy, ParentRecordID, Details, ShowInSelfService)
	values (NEWID(), '934d80e020e2eb4359e59c47168f69db78f7fd9541', 'History', GETDATE(), 'PKE-Mover',@v_pkeID, 'This ProductCatalogItem was moved to the Service Pack ' + @vi_sp,0)

	PRINT 'Transfer Products'
	update Product set LinkPKEID = @vi_newPKEID where LinkPKEID = @v_PKEID

	PRINT 'Transfer Assignments'
	IF (@v_optional = 1)
	update ServiceAssignment set Assigned = 1, HaveAssignedService = 1 where ProductCatalogItemID = @vi_newPKEID
	and CustomerID in (select CustomerID from ServiceAssignment where ProductCatalogItemID = @v_PKEID and Assigned = 1)
	
	IF (@v_optional = 0)
	update ServiceAssignment set Assigned = 1, HaveAssignedService = 1 where ProductCatalogItemID = @vi_newPKEID
	and CustomerID in (select CustomerID from ServiceAssignment 
					   where ProductCatalogItemID = '' 
					   and Assigned = 1
					   and ServicePackageID = (select top 1 servicepackageid from ServiceAssignment
																			   where ProductCatalogItemID = @v_pkeID))

	update ServiceAssignment set Assigned = 0 where ProductCatalogItemID = @v_PKEID and Assigned = 1

	update ServiceAssignment set Assigned = 1 where ProductCatalogItemID = '' and ServicePackageID = @v_spID 		
	and CustomerID in (select CustomerID from ServiceAssignment 
					   where ProductCatalogItemID = '' 
					   and Assigned = 1
					   and ServicePackageID = (select top 1 servicepackageid from ServiceAssignment where ProductCatalogItemID = @v_pkeID))
	
	PRINT 'Completed'
END 