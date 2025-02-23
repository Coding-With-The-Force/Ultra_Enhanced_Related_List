public with sharing class Org_Ultra_Related_List_Controller {
    private static Org_DataTable_Column_Wrapper actionsColumn = new Org_DataTable_Column_Wrapper();

    @AuraEnabled
    public static String getObjectLabel(String objectAPIName){
        List<Schema.DescribeSObjectResult> describeSobjectsResult = Schema.describeSObjects(new List<String>{objectAPIName}); // this can accept list of strings, we describe only one object here
        String objectLabel = describeSobjectsResult[0].getLabel();
        return objectLabel;
    }

    @AuraEnabled
    public static List<UE_Related_List_Style__mdt> getColumnStyles(String objectType, String recordTypeName){
        List<UE_Related_List_Column__mdt> columnMetadata = getRelatedListColumnMetadata(objectType, recordTypeName);
        List<UE_Related_List_Style__mdt> columnStylesList = [SELECT Id, Comparison_Criteria__c, Field_To_Compare__c, Field_To_Compare__r.Field_Name__c,
                Comparison_Value__c, CSS_Class_Name__c, UE_Related_List_Column_Link__c,
                UE_Related_List_Column_Link__r.Field_Name__c FROM UE_Related_List_Style__mdt
        WHERE UE_Related_List_Column_Link__c IN : columnMetadata];
        return columnStylesList;
    }

    @AuraEnabled
    public static String getRecordTypeId(Id recordId){
        String recordTypeName = 'default';
        List<SObject> recordList = new List<SObject>();
        String query = 'SELECT RecordTypeId FROM ' + recordId.getSobjectType().getDescribe().getName() + ' WHERE Id = :recordId';
        try{
            recordList = Database.query(query);
        }
        catch(Exception exp){
            return recordTypeName;
        }
        if(!recordList.isEmpty()){
            recordTypeName = [SELECT Id, Name FROM RecordType WHERE Id = :(Id)recordList[0].get('RecordTypeId')]?.Name;
        }
        return recordTypeName;
    }

    @AuraEnabled
    public static List<SObject> getTableDataController(String recordId, String relatedObjectField, String objectType, String recordTypeName){
        List<SObject> tableData = new List<SObject>();
        try {
            String query = buildObjectQuery(objectType, relatedObjectField, recordTypeName);
            tableData = database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return tableData;
    }

    @AuraEnabled
    public static List<UE_Related_List_Page_Size__mdt> getTableSizeOptionsController(String objectType){
        List<UE_Related_List_Page_Size__mdt> columnSizeOptions = new List<UE_Related_List_Page_Size__mdt>();
        columnSizeOptions = [SELECT Id, Label, Page_Size__c FROM UE_Related_List_Page_Size__mdt
        WHERE Object_Name__c = :objectType ORDER BY Page_Size__c LIMIT 1000];
        return columnSizeOptions;
    }

    @AuraEnabled
    public static List<Org_DataTable_Column_Wrapper> getDataTableColumnsController(String objectType, String recordTypeName){

        List<Org_DataTable_Column_Wrapper> columnData = new List<Org_DataTable_Column_Wrapper>();
        List<UE_Related_List_Column__mdt> columnMetadata = getRelatedListColumnMetadata(objectType, recordTypeName);

        if(!columnMetadata.isEmpty()){
            columnData = buildColumnData(columnMetadata, recordTypeName);
        }

        return columnData;
    }

    @AuraEnabled
    public static Map<String, String> getSearchableFields(String objectType, String recordTypeName){
        Map<String, String> searchableFields = new Map<String, String>();
        List<UE_Related_List_Column__mdt> columnMetadata = getRelatedListColumnMetadata(objectType, recordTypeName);
        for(UE_Related_List_Column__mdt column: columnMetadata){
            if(column.Allow_Search__c){
                searchableFields.put(column.Field_Name__c, column.Field_Name__c);
            }
        }
        return searchableFields;
    }

    @AuraEnabled
    public static List<String> getViewRecordFields(String objectType, String recordTypeName){
        List<String> viewRecordFields = new List<String>();
        List<UE_Related_List_Column__mdt> fieldsToQuery = getRelatedListColumnMetadata(objectType, recordTypeName);
        for(UE_Related_List_Column__mdt field: fieldsToQuery){
            if(field.Column_Type__c != 'action' && field.Show_on_View_Only_Form__c){
                viewRecordFields.add(field.Field_Name__c);
            }
        }

        return viewRecordFields;
    }

    @AuraEnabled
    public static String massDeleteRecords(String recordIds, String objectType){
        String returnMsg = 'Deletions Failed';
        Set<Id> recIds = (Set<Id>)JSON.deserialize(recordIds, Set<Id>.class);
        Schema.SObjectType dataType = Schema.getGlobalDescribe().get(objectType);
        List<SObject> deletes = new List<SObject>();
        for(Id recId: recIds){
            SObject newSObject = dataType.newSObject();
            newSObject.Id = recId;
            deletes.add(newSObject);
        }

        try{
            database.delete(deletes);
            returnMsg = 'Deletes Successful';
        }
        catch(Exception err){
            returnMsg = 'There was an error deleting records: ' + err.getMessage();
        }
        return returnMsg;
    }

    @AuraEnabled
    public static String saveTableDataToServer(String objectType, String tableDataJSON){
        List<Object> objectsReceived = (List<Object>)JSON.deserializeUntyped(tableDataJSON);
        List<SObject> convertedSObjects = new List<SObject>();

        for(Object val: objectsReceived){
            Map<String, Object> objectMap = (Map<String, Object>)val;
            Schema.SObjectType dataType = Schema.getGlobalDescribe().get(objectType);
            SObject convertedObject = dataType.newSObject();

            Map<String, Schema.SObjectField> fields = dataType.getDescribe().fields.getMap();
            for(String fieldName: objectMap.keySet())
            {
                Schema.SObjectField field = fields.get(fieldName);
                Schema.DisplayType fieldType = fields.get(fieldName).getDescribe().getType();
                if(field != null)
                {
                    if(fieldType == Schema.DisplayType.CURRENCY || fieldType == Schema.DisplayType.LONG
                            || fieldType == Schema.DisplayType.PERCENT || fieldType == Schema.DisplayType.DOUBLE){
                        convertedObject.put(fieldName, Double.valueOf(objectMap.get(fieldName)));
                    }
                    else if(fieldType == Schema.DisplayType.INTEGER){
                        convertedObject.put(fieldName, Integer.valueOf(objectMap.get(fieldName)));
                    }
                    else if(fieldType == Schema.DisplayType.DATE){
                        Date dateValue = Date.valueOf((String)objectMap.get(fieldName));
                        String dateFormatted = dateValue.format();
                        convertedObject.put(fieldName, Date.parse(dateFormatted));
                    }
                    else if(fieldType == Schema.DisplayType.DATETIME){
                        convertedObject.put(fieldName, (Datetime)JSON.deserialize((String)objectMap.get(fieldName), Datetime.class));
                    }
                    else if(fieldType == Schema.DisplayType.BOOLEAN){
                        convertedObject.put(fieldName, Boolean.valueOf(objectMap.get(fieldName)));
                    }
                    else{
                        convertedObject.put(fieldName, String.valueOf(objectMap.get(fieldName)));
                    }
                }
            }

            convertedSObjects.add(convertedObject);
        }

        String returnMsg = 'The update failed';
        try{
            database.update(convertedSObjects, true);
            returnMsg = 'Successfully updated all records';
        }
        catch(Exception err){
            returnMsg = 'There was an error updating the records: ' + err.getMessage();
        }
        return returnMsg;
    }
    @TestVisible
    private static List<UE_Related_List_Column__mdt> getRelatedListColumnMetadata(String objectType, String recordTypeName){
        List<String> fieldsToExclude = getUserFieldsToExclude(objectType);
        List<UE_Related_List_Column__mdt> dataColumns = new List<UE_Related_List_Column__mdt>();
        String query = 'SELECT Id, Label, Column_Order__c, Allow_Editing__c, Allow_Sorting__c, URL_Id__c, Field_Label__c,\n' +
                'Allow_Text_Wrap__c, Column_Type__c, Field_Name__c, Initial_Column_Width__c, Object_Developer_Name__c,\n' +
                'Show_on_View_Only_Form__c, Record_Type_Name__c, Show_on_Table__c, Allow_Search__c, Show_on_New_Record_Form__c\n' +
                'FROM UE_Related_List_Column__mdt WHERE Object_Developer_Name__c = :objectType ';
        if(!String.isBlank(recordTypeName)){
            query += 'AND (Record_Type_Name__c LIKE \'%'+ recordTypeName + '%\' OR Record_Type_Name__c LIKE \'%default\') ';
        }
        if(!fieldsToExclude.isEmpty()){
            query += 'AND Field_Label__c NOT IN :fieldsToExclude ';
        }
        query += 'ORDER BY Column_Order__c ASC LIMIT 1000';

        dataColumns = Database.query(query);
        return dataColumns;
    }

    @AuraEnabled
    public static List<String> getUserFieldsToExclude(String objectType){
        List<String> fieldsToExclude = new List<String>();
        String excludedColumns = '';

        List<Org_Related_List_User_Preference__c> userPreferences = [SELECT Id, User__c, Fields_Excluded_From_Table__c
        FROM Org_Related_List_User_Preference__c WHERE Object_Developer_Name__c = :objectType
        AND User__c = :UserInfo.getUserId() LIMIT 1];

        if(!userPreferences.isEmpty()){
            excludedColumns = userPreferences[0].Fields_Excluded_From_Table__c;
        }
        else if(userPreferences.isEmpty()){
            excludedColumns = [SELECT Id, User__c, Fields_Excluded_From_Table__c
            FROM Org_Related_List_User_Preference__c WHERE Object_Developer_Name__c = :objectType
            AND Default_Excluded_Fields__c = TRUE LIMIT 1]?.Fields_Excluded_From_Table__c;
        }

        if(String.isBlank(excludedColumns)){return fieldsToExclude;}

        fieldsToExclude = excludedColumns.split(',');

        return fieldsToExclude;
    }

    @AuraEnabled
    public static List<String> getUserFieldsToInclude(String excludedFields, String objectType){
        List<UE_Related_List_Column__mdt> dataColumns = [SELECT Id, Label, Column_Order__c, Allow_Editing__c, Allow_Sorting__c, URL_Id__c, Field_Label__c,
                Allow_Text_Wrap__c, Column_Type__c, Field_Name__c, Initial_Column_Width__c, Object_Developer_Name__c,
                Show_on_View_Only_Form__c, Record_Type_Name__c, Show_on_Table__c, Allow_Search__c, Show_on_New_Record_Form__c
                FROM UE_Related_List_Column__mdt WHERE Object_Developer_Name__c = :objectType AND Show_on_Table__c = TRUE AND Column_Type__c != 'action'];
        List<String> excludedFieldNames = (List<String>)JSON.deserialize(excludedFields, List<String>.class);

        Map<String, String> fieldMap = new Map<String, String>();
        for(UE_Related_List_Column__mdt column: dataColumns){
            fieldMap.put(column.Field_Label__c, column.Field_Label__c);
        }
        if(excludedFields == null){return fieldMap.values();}
        for(String fieldName: excludedFieldNames){
            if(fieldMap.containsKey(fieldName)){
                fieldMap.remove(fieldName);
            }
        }
        return fieldMap.values();
    }

    @AuraEnabled
    public static void saveUserExcludedFields(String objectType, String fieldsToExcludePassed){
        System.debug('Fields to exclude ::: ' + fieldsToExcludePassed);
        String fieldsToExclude = createExcludedColumnsString(fieldsToExcludePassed);
        List<Org_Related_List_User_Preference__c> userPreferences = [SELECT Id, User__c, Fields_Excluded_From_Table__c
        FROM Org_Related_List_User_Preference__c WHERE Object_Developer_Name__c = :objectType
        AND User__c = :UserInfo.getUserId() LIMIT 1];

        if(!userPreferences.isEmpty()){
            userPreferences[0].Fields_Excluded_From_Table__c = fieldsToExclude;
            try{
                update userPreferences;
            }
            catch(Exception ex){
                throw new AuraHandledException('There was an error saving the selected fields: ' + ex.getMessage());
            }
        }
        else{
            Org_Related_List_User_Preference__c relatedListUserPreference = new Org_Related_List_User_Preference__c();
            relatedListUserPreference.User__c = UserInfo.getUserId();
            relatedListUserPreference.Object_Developer_Name__c = objectType;
            relatedListUserPreference.Fields_Excluded_From_Table__c = fieldsToExclude;
            try{
                insert relatedListUserPreference;
            }
            catch(Exception ex){
                throw new AuraHandledException('There was an error saving the selected fields: ' + ex.getMessage());
            }
        }
    }

    private static String createExcludedColumnsString(String fieldsToExcludePassed){
        String fieldsToExclude = '';
        List<String> userSelectedFields = (List<String>)JSON.deserialize(fieldsToExcludePassed, List<String>.class);
        for(String field: userSelectedFields){
            fieldsToExclude += field + ',';
        }
        fieldsToExclude.removeEnd(',');
        return fieldsToExclude;
    }

    @TestVisible
    private static List<Org_DataTable_Column_Wrapper> buildColumnData(List<UE_Related_List_Column__mdt> columnMetadata, String recordTypeName)
    {
        List<UE_Related_List_Style__mdt> columnStylesList = [SELECT Id, Comparison_Criteria__c, Field_To_Compare__c, Field_To_Compare__r.Field_Name__c,
                Comparison_Value__c, CSS_Class_Name__c, UE_Related_List_Column_Link__c,
                UE_Related_List_Column_Link__r.Field_Name__c FROM UE_Related_List_Style__mdt
        WHERE UE_Related_List_Column_Link__c IN : columnMetadata];

        Map<Id, UE_Related_List_Style__mdt> styleByColumnMap = new Map<Id, UE_Related_List_Style__mdt>();
        for(UE_Related_List_Style__mdt style: columnStylesList){
            styleByColumnMap.put(style.UE_Related_List_Column_Link__c, style);
        }

        List<Org_DataTable_Column_Wrapper> dataColumnObjectList = new List<Org_DataTable_Column_Wrapper>();
        for(UE_Related_List_Column__mdt column: columnMetadata){
            UE_Related_List_Style__mdt style = styleByColumnMap.get(column.Id);
            if(!column.Show_on_Table__c){
                continue;
            }
            if(column.Column_Type__c == 'action'){
                buildActionColumn(column);
                continue;
            }
            Org_DataTable_Column_Wrapper dataColumn = new Org_DataTable_Column_Wrapper();
            dataColumn.editable = column.Allow_Editing__c;
            dataColumn.sortable = column.Allow_Sorting__c;
            dataColumn.label = column.Field_Label__c;
            dataColumn.type = column.Column_Type__c;
            if(column.Column_Type__c == 'url'){
                dataColumn.fieldName = column.URL_Id__c;
            }
            else if (column.Column_Type__c != 'image'){
                dataColumn.fieldName = column.Field_Name__c;
            }
            if(style != null){
                dataColumn.cellAttributes = buildCellAttributes(column, recordTypeName);
            }
            dataColumn.typeAttributes = buildColumnTypeAttributes(column);
            dataColumnObjectList.add(dataColumn);
        }

        dataColumnObjectList.add(actionsColumn);

        return dataColumnObjectList;
    }
    @TestVisible
    private static void buildActionColumn(UE_Related_List_Column__mdt actionsColumnMetadata){
        if(actionsColumn.typeAttributes?.rowActions == null){
            actionsColumn.type = actionsColumnMetadata.Column_Type__c;
            actionsColumn.fieldName = actionsColumnMetadata.Field_Name__c;
            actionsColumn.typeAttributes = buildColumnTypeAttributes(actionsColumnMetadata);
        }
        else{
            Org_DataTable_RowActions rowAction = new Org_DataTable_RowActions();
            rowAction.label = actionsColumnMetadata.Field_Label__c;
            rowAction.name = actionsColumnMetadata.Field_Name__c;
            actionsColumn.typeAttributes.rowActions.add(rowAction);
        }
    }
    @TestVisible
    private static Org_DataTable_TypeAttributes_Wrapper buildColumnTypeAttributes(UE_Related_List_Column__mdt dataColumn){
        Org_DataTable_TypeAttributes_Wrapper columnTypeAttributesList = new Org_DataTable_TypeAttributes_Wrapper();
        if(dataColumn.Column_Type__c == 'date-local'){
            columnTypeAttributesList.day = '2-digit';
            columnTypeAttributesList.month = '2-digit';
        }
        else if(dataColumn.Column_Type__c == 'url'){
            columnTypeAttributesList.target = '_blank';
            columnTypeAttributesList.label = new Org_DataTable_Label_Attribute_Details();
            columnTypeAttributesList.label.fieldName = dataColumn.Field_Name__c;
        }
        else if(dataColumn.Column_Type__c == 'action'){
            columnTypeAttributesList.rowActions = buildActionAttributeDetails(dataColumn);
        }
        else if(dataColumn.Column_Type__c == 'picklist'){
            columnTypeAttributesList.value = new Org_DataTable_Label_Attribute_Details();
            columnTypeAttributesList.value.fieldName = dataColumn.Field_Name__c;
            columnTypeAttributesList.options = getPicklistOptions(dataColumn.Object_Developer_Name__c, dataColumn.Field_Name__c);
        }

        return columnTypeAttributesList;
    }

    @TestVisible
    private static Org_DataTable_CellAttributes_Wrapper buildCellAttributes(UE_Related_List_Column__mdt columnMetadata, String recordTypeName){
        Org_DataTable_CellAttributes_Wrapper cellAttributes = new Org_DataTable_CellAttributes_Wrapper();
        Org_DataTable_Class className = new Org_DataTable_Class();
        className.fieldName = columnMetadata.Object_Developer_Name__c + recordTypeName +columnMetadata.Field_Name__c;
        cellAttributes.cssclass = className;
        return cellAttributes;
    }

    @TestVisible
    private static List<Org_DataTable_Select_Option> getPicklistOptions(String objectName, String fieldName){
        List<Org_DataTable_Select_Option> selectOptions = new List<Org_DataTable_Select_Option>();
        Schema.SObjectType objectSchema = Schema.getGlobalDescribe().get(objectName) ;
        Schema.DescribeSObjectResult objectDescription = objectSchema.getDescribe() ;
        Map<String,Schema.SObjectField> fields = objectDescription.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : picklistEntries){
            Org_DataTable_Select_Option newOption = new Org_DataTable_Select_Option();
            newOption.value = pickListVal.getValue();
            newOption.label = pickListVal.getLabel();
            selectOptions.add(newOption);
        }
        return selectOptions;
    }

    @TestVisible
    private static List<Org_DataTable_RowActions> buildActionAttributeDetails(UE_Related_List_Column__mdt dataColumn){
        List<Org_DataTable_RowActions> rowActionDetailsList = new List<Org_DataTable_RowActions>();
        Org_DataTable_RowActions rowActionDetail = new Org_DataTable_RowActions();
        rowActionDetail.label = dataColumn.Field_Label__c;
        rowActionDetail.name = dataColumn.Field_Name__c;
        rowActionDetailsList.add(rowActionDetail);
        return rowActionDetailsList;
    }

    @TestVisible
    private static String buildObjectQuery(String objectType, String relatedObjectField, String recordTypeName){
        String sObjectQuery = '';
        List<UE_Related_List_Column__mdt> fieldsToQuery = getRelatedListColumnMetadata(objectType, recordTypeName);

        if(fieldsToQuery.isEmpty()){
            return sObjectQuery;
        }

        sObjectQuery = 'SELECT Id, ';
        for(UE_Related_List_Column__mdt column: fieldsToQuery){
            if(column.Column_Type__c != 'action' && column.Column_Type__c != 'url'){
                sObjectQuery += column.Field_Name__c + ',';
            }
            else if(column.Column_Type__c == 'url'){
                sObjectQuery += column.Field_Name__c + ',';

                if(!sObjectQuery.contains(column.URL_Id__c))
                {
                    sObjectQuery += column.URL_Id__c	+ ',';
                }
            }
        }

        sObjectQuery = sObjectQuery.removeEnd(',');
        sObjectQuery += ' FROM ' + objectType + ' WHERE ' + relatedObjectField + ' = :recordId';
        return sObjectQuery;
    }
    //Slapped in here so I don't forget methods to evaluate access in an asbtract manner
    //Schema.SObjectType objType = ((SObject) Type.forName(objectType.newInstance)).getSObjectType();
    //objType.getDescribe().isDeletable()
    //MyRecord.getSobjectType().getDescribe().isDeletable()
}