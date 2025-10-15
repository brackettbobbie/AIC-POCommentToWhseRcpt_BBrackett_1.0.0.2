codeunit 50107 "PO Comment Management"
{
    [EventSubscriber(ObjectType::Codeunit, 5750, 'OnBeforeWhseReceiptLineInsert', '', false, false)]
    local procedure OnBeforeWhseReceiptLineInsert(var WarehouseReceiptLine: Record "Warehouse Receipt Line")
    var
        PurchLine: Record "Purchase Line";
        WhseReceiptLine: Record "Warehouse Receipt Line";
        BaseLineNo: Integer;
        NextLineNo: Integer;
        CommentsToAdd: Integer;
    begin
        // Only proceed if this is a Purchase Order line
        if WarehouseReceiptLine."Source Document" <> WarehouseReceiptLine."Source Document"::"Purchase Order" then exit;
        // Skip if this is already a comment line (Quantity = 0)
        if WarehouseReceiptLine.Quantity = 0 then exit;
        BaseLineNo:=WarehouseReceiptLine."Line No.";
        // First, count user comments until we hit an item
        CommentsToAdd:=0;
        PurchLine.SetRange("Document Type", PurchLine."Document Type"::Order);
        PurchLine.SetRange("Document No.", WarehouseReceiptLine."Source No.");
        PurchLine.SetFilter("Line No.", '>%1', WarehouseReceiptLine."Source Line No.");
        if PurchLine.FindSet()then begin
            repeat // Stop if we hit an item line
                if PurchLine.Type = PurchLine.Type::Item then break;
                // Count if it's a user comment
                if(PurchLine.Type = PurchLine.Type::" ") and (PurchLine."No." = '')then CommentsToAdd+=1;
            until PurchLine.Next() = 0;
        end;
        if CommentsToAdd = 0 then exit;
        // Shift existing lines down to make room
        WhseReceiptLine.SetRange("No.", WarehouseReceiptLine."No.");
        WhseReceiptLine.SetFilter("Line No.", '>%1', BaseLineNo);
        if WhseReceiptLine.FindSet()then begin
            repeat WhseReceiptLine.Validate("Line No.", WhseReceiptLine."Line No." + CommentsToAdd);
                WhseReceiptLine.Modify();
            until WhseReceiptLine.Next() = 0;
        end;
        // Insert the comment lines
        PurchLine.Reset();
        PurchLine.SetRange("Document Type", PurchLine."Document Type"::Order);
        PurchLine.SetRange("Document No.", WarehouseReceiptLine."Source No.");
        PurchLine.SetFilter("Line No.", '>%1', WarehouseReceiptLine."Source Line No.");
        NextLineNo:=BaseLineNo + 1;
        if PurchLine.FindSet()then begin
            repeat // Stop if we hit an item line
                if PurchLine.Type = PurchLine.Type::Item then break;
                // Insert if it's a user comment
                if(PurchLine.Type = PurchLine.Type::" ") and (PurchLine."No." = '')then begin
                    Clear(WhseReceiptLine);
                    WhseReceiptLine.Init();
                    WhseReceiptLine.Validate("No.", WarehouseReceiptLine."No.");
                    WhseReceiptLine.Validate("Line No.", NextLineNo);
                    WhseReceiptLine.Validate("Source Document", WhseReceiptLine."Source Document"::"Purchase Order");
                    WhseReceiptLine.Validate("Source No.", PurchLine."Document No.");
                    WhseReceiptLine.Validate("Source Line No.", PurchLine."Line No.");
                    WhseReceiptLine.Description:=PurchLine.Description;
                    if PurchLine."Description 2" <> '' then WhseReceiptLine."Description 2":=PurchLine."Description 2";
                    WhseReceiptLine.Quantity:=0;
                    WhseReceiptLine.Insert(true);
                    NextLineNo+=1;
                end;
            until PurchLine.Next() = 0;
        end;
    end;
}
