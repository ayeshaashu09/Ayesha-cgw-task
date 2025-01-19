import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import fetchInvoiceData from '@salesforce/apex/InvoiceController.fetchInvoiceData';

export default class CreateInvoicePage extends NavigationMixin(LightningElement) {
    @api recordId; 
    @track data = [];
    @track error;

    columns = [
        { label: 'Origin Record', fieldName: 'origin_record' },
        { label: 'Account', fieldName: 'account' },
        { label: 'Invoice Date', fieldName: 'invoice_date' },
        { label: 'Invoice Due Date', fieldName: 'invoice_due_date' },
        { label: 'Child Relationship Name', fieldName: 'child_relationship_name' },
        { label: 'Line Item Description', fieldName: 'line_item_description' },
        { label: 'Line Item Quantity', fieldName: 'line_item_quantity' },
        { label: 'Line Item Unit Price', fieldName: 'line_item_unit_price' }
    ];

    connectedCallback() {
        if (this.recordId) {
            fetchInvoiceData({ originRecordId: this.recordId })
                .then(result => {
                    // Process the result to create an array of line items
                    this.data = result.line_items.map(item => ({
                        origin_record: this.recordId,
                        account: result.account,
                        invoice_date: result.invoice_date,
                        invoice_due_date: result.invoice_due_date,
                        child_relationship_name: result.child_relationship_name,
                        line_item_description: item.description,
                        line_item_quantity: item.quantity,
                        line_item_unit_price: item.unit_price
                    }));
                })
                .catch(error => {
                    this.error = 'Error fetching data: ' + error.body.message;
                });
        } else {
            this.error = 'No recordId found for the Opportunity.';
        }
    }

   handleNavigate() {
    // Construct the base URL
    let url = `/apex/InvoiceDetails?origin_record=${this.recordId}` + 
              `&account=${this.data[0].account}` + 
              `&invoice_date=${this.data[0].invoice_date}` + 
              `&invoice_due_date=${this.data[0].invoice_due_date}` + 
              `&child_relationship_name=${this.data[0].child_relationship_name}`;

    // Append all line items to the URL as query parameters
    this.data.forEach((item, index) => {
        url += `&line_item_description_${index}=${item.line_item_description}` +
               `&line_item_quantity_${index}=${item.line_item_quantity}` +
               `&line_item_unit_price_${index}=${item.line_item_unit_price}`;
    });

    // Navigate to the new page
    this[NavigationMixin.Navigate]({
        type: 'standard__webPage',
        attributes: {
            url: url
        }
    });
}
}