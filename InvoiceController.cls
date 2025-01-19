public with sharing class InvoiceController {


public String originRecord { get; set; }
public String account { get; set; }
public String invoiceDate { get; set; }
public String invoiceDueDate { get; set; }
public String childRelationshipName { get; set; }
public List<Workshop_Article__c> lineItems { get; set; }

public InvoiceController() {
    // Fetch parameters from the current page
    originRecord = ApexPages.currentPage().getParameters().get('origin_record');
    account = ApexPages.currentPage().getParameters().get('account');
    invoiceDate = ApexPages.currentPage().getParameters().get('invoice_date');
    invoiceDueDate = ApexPages.currentPage().getParameters().get('invoice_due_date');
    childRelationshipName = ApexPages.currentPage().getParameters().get('child_relationship_name');

    // Query line items based on the Opportunity (or related record)
    if (originRecord != null) {
        lineItems = [
            SELECT Description__c, Quantity__c, Total_Article_price__c
            FROM Workshop_Article__c
            WHERE Workshop__c = :originRecord
        ];
    } else {
        lineItems = new List<Workshop_Article__c>();
    }
}


public PageReference showJSON() {
    String originRecordId = ApexPages.currentPage().getParameters().get('origin_record');
    
    // Query Opportunity details
    Opportunity opp = [
        SELECT Id, AccountId, CloseDate, Payment_Date__c, StageName
        FROM Opportunity
        WHERE Id = :originRecordId
        LIMIT 1
    ];
    
    // Query Account and related Contact details
    Account acc = [
        SELECT Id, Type, (SELECT Id, Name FROM Contacts LIMIT 1)
        FROM Account
        WHERE Id = :opp.AccountId
        LIMIT 1
    ];

    // Query Workshop SKU details
    List<Workshop_Article__c> lineItems = [
        SELECT Description__c, Quantity__c, Total_Article_price__c
        FROM Workshop_Article__c
        WHERE Workshop__c = :originRecordId
    ];

    // Construct the JSON map
    Map<String, Object> invoiceData = new Map<String, Object>();
    invoiceData.put('Type', acc.Type);

    if (!acc.Contacts.isEmpty()) {
        invoiceData.put('Contact', new Map<String, String>{
            'ContactID' => acc.Contacts[0].Id,
            'ContactName' => acc.Contacts[0].Name
        });
    }

    // Add DueDate
invoiceData.put('DueDate',  opp.Payment_Date__c);


    // Add LineItems
    List<Map<String, Object>> lineItemList = new List<Map<String, Object>>();
    for (Workshop_Article__c line : lineItems) {
        Map<String, Object> lineItem = new Map<String, Object>();
        lineItem.put('Description', line.Description__c);
        lineItem.put('Quantity', String.valueOf(line.Quantity__c));
        lineItem.put('UnitAmount', String.valueOf(line.Total_Article_price__c));
        lineItem.put('AccountCode', '200'); // Default Account Code
        lineItemList.add(lineItem);
    }
    invoiceData.put('LineItems', lineItemList);

    // Add Status
    invoiceData.put('Status', opp.StageName);

    // Serialize the JSON data
    String jsonString = JSON.serializePretty(invoiceData);

    // Redirect to InvoiceJSONPage with the JSON string
    PageReference jsonPage = new PageReference('/apex/InvoiceJSONPage');
    jsonPage.getParameters().put('jsonString', jsonString);

    return jsonPage;
}


@AuraEnabled
public static Map<String, Object> fetchInvoiceData(String originRecordId) {
    Map<String, Object> result = new Map<String, Object>();
    try {
        // Query the Opportunity record
        Opportunity opp = [
            SELECT Id, AccountId, CloseDate, Payment_Date__c
            FROM Opportunity
            WHERE Id = :originRecordId
            LIMIT 1
        ];

        if (opp == null) {
            throw new AuraHandledException('No Opportunity found with the given Id.');
        }

        // Query the related Workshop_Article__c records (Line Items)
        List<Workshop_Article__c> lineItems = [
            SELECT Description__c, Quantity__c, Total_Article_price__c
            FROM Workshop_Article__c
            WHERE Workshop__c = :originRecordId
        ];

        // Prepare the result map
        result.put('origin_record', opp.Id);
        result.put('account', opp.AccountId);
        result.put('invoice_date', String.valueOf(opp.CloseDate));
        result.put('invoice_due_date', String.valueOf(opp.Payment_Date__c));
        result.put('child_relationship_name', 'Workshop_Article__r'); 

        // Serialize line items as a list of maps
        List<Map<String, String>> lineItemList = new List<Map<String, String>>();
        List<Line_Item__c> invoiceLineItems = new List<Line_Item__c>();
        
        for (Workshop_Article__c lineItem : lineItems) {
            // Create a map for the line item details to return
            Map<String, String> lineItemMap = new Map<String, String>();
            lineItemMap.put('description', lineItem.Description__c);
            lineItemMap.put('quantity', String.valueOf(lineItem.Quantity__c));
            lineItemMap.put('unit_price', String.valueOf(lineItem.Total_Article_price__c));
            lineItemList.add(lineItemMap);
        }

     

        // Add line items to result map
        result.put('line_items', lineItemList);

        return result;
    } catch (Exception e) {
        throw new AuraHandledException('Error fetching data: ' + e.getMessage());
    }
}

public PageReference createInvoice() {
    try {
        // Create the Invoice record
        Invoice__c invoice = new Invoice__c(
            Opportunity__c = originRecord,
            Account__c = account,
            Invoice_Date__c = Date.valueOf(invoiceDate),
            Due_Date__c = Date.valueOf(invoiceDueDate)
        );
        insert invoice;

        // Create associated Line Item records
        List<Line_Item__c> invoiceLineItems = new List<Line_Item__c>();
        for (Workshop_Article__c item : lineItems) {
            invoiceLineItems.add(new Line_Item__c(
                Invoice__c = invoice.Id,
                Line_Description__c = item.Description__c,
                Quantity__c = item.Quantity__c,
                Unit_Price__c = item.Total_Article_price__c
            ));
        }
        if (!invoiceLineItems.isEmpty()) {
            insert invoiceLineItems;
        }

        // Navigate to the newly created Invoice record
        PageReference pageRef = new PageReference('/' + invoice.Id);
        pageRef.setRedirect(true);
        return pageRef;

    } catch (Exception e) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error creating invoice: ' + e.getMessage()));
        return null;
    }
}

}
