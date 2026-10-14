import io
from decimal import Decimal
from django.conf import settings
from django.utils import timezone
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import inch, mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether, HRFlowable
)
from reportlab.graphics.shapes import Drawing
from reportlab.graphics.barcode import qr
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    """
    Two-pass canvas to dynamically compute and print total page count 'Page X of Y'.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(num_pages)
            super().showPage()
        super().save()

    def draw_page_number(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor('#64748B'))
        
        # Bottom rule
        self.setStrokeColor(colors.HexColor('#E2E8F0'))
        self.setLineWidth(0.5)
        self.line(36, 36, 559, 36)
        
        # Footer text
        footer_text = "Storefront Marketplace • Bangladesh • Official Tax Invoice • support@storefront.com"
        self.drawString(36, 24, footer_text)
        
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(559, 24, page_str)
        self.restoreState()


class OrderInvoiceService:
    @staticmethod
    def generate_invoice_pdf(order) -> bytes:
        """
        Builds a comprehensive, branded tax invoice PDF for an Order.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=A4,
            leftMargin=36,
            rightMargin=36,
            topMargin=36,
            bottomMargin=54,
        )

        styles = getSampleStyleSheet()
        
        # Custom Typography
        brand_title = ParagraphStyle(
            'BrandTitle',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=18,
            leading=22,
            textColor=colors.HexColor('#0F172A'),
        )
        brand_subtitle = ParagraphStyle(
            'BrandSubtitle',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8.5,
            leading=11,
            textColor=colors.HexColor('#64748B'),
        )
        invoice_title = ParagraphStyle(
            'InvoiceTitle',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=16,
            leading=20,
            alignment=2, # Right aligned
            textColor=colors.HexColor('#0F172A'),
        )
        invoice_meta = ParagraphStyle(
            'InvoiceMeta',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8.5,
            leading=12,
            alignment=2,
            textColor=colors.HexColor('#334155'),
        )
        section_heading = ParagraphStyle(
            'SectionHeading',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=10,
            leading=14,
            textColor=colors.HexColor('#0F172A'),
        )
        body_text = ParagraphStyle(
            'BodyText',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8.5,
            leading=12,
            textColor=colors.HexColor('#1E293B'),
        )
        body_bold = ParagraphStyle(
            'BodyBold',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=8.5,
            leading=12,
            textColor=colors.HexColor('#0F172A'),
        )
        body_muted = ParagraphStyle(
            'BodyMuted',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8,
            leading=10,
            textColor=colors.HexColor('#64748B'),
        )
        table_hdr = ParagraphStyle(
            'TableHdr',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=8,
            leading=10,
            textColor=colors.HexColor('#334155'),
        )
        table_cell = ParagraphStyle(
            'TableCell',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8,
            leading=11,
            textColor=colors.HexColor('#1E293B'),
        )
        table_cell_bold = ParagraphStyle(
            'TableCellBold',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=8,
            leading=11,
            textColor=colors.HexColor('#0F172A'),
        )
        table_cell_right = ParagraphStyle(
            'TableCellRight',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8,
            leading=11,
            alignment=2,
            textColor=colors.HexColor('#1E293B'),
        )

        elements = []

        # ── 1. Top Header Row: Brand Logo & Title vs Invoice Reference ──
        invoice_no = f"INV-{order.id:06d}-{order.created_at.strftime('%Y%m%d')}"
        created_str = order.created_at.strftime('%d %b %Y, %I:%M %p')
        status_color = '#10B981' if order.payment_status == 'PAID' else '#F59E0B'
        
        header_left = [
            Paragraph("STOREFRONT MARKETPLACE", brand_title),
            Spacer(1, 2),
            Paragraph("Premier Multi-Vendor E-Commerce Platform", brand_subtitle),
            Paragraph("VAT Reg / BIN: 001928374-0101 • Dhaka, Bangladesh", brand_subtitle),
        ]
        header_right = [
            Paragraph("TAX INVOICE / বিল", invoice_title),
            Spacer(1, 4),
            Paragraph(f"<b>Invoice #:</b> {invoice_no}", invoice_meta),
            Paragraph(f"<b>Order Date:</b> {created_str}", invoice_meta),
            Paragraph(f"<b>Payment:</b> <font color='{status_color}'><b>{order.payment_status}</b></font> ({order.payment_method})", invoice_meta),
        ]

        header_table = Table(
            [[header_left, header_right]],
            colWidths=[310, 213],
        )
        header_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
        ]))
        elements.append(header_table)
        elements.append(Spacer(1, 14))
        elements.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#E2E8F0'), spaceAfter=14))

        # ── 2. Meta Block: Bill To / Ship To & Verification QR Code ──
        customer = order.customer
        customer_name = customer.get_full_name() or customer.username or "Customer"
        customer_email = customer.email or "N/A"
        
        addr = order.delivery_address
        if addr:
            phone_str = getattr(addr, 'phone_number', '') or getattr(addr, 'phone', '') or getattr(customer, 'phone', 'N/A')
            line = getattr(addr, 'address_line', '') or getattr(addr, 'street_address', '') or ""
            area_str = f", {addr.area}" if getattr(addr, 'area', '') else ""
            city_str = getattr(addr, 'city', '') or "Dhaka"
            addr_line1 = f"{line}{area_str}" if line else "Standard Delivery Address"
            addr_line2 = f"{city_str}, Bangladesh"
        else:
            phone_str = getattr(customer, 'phone', 'N/A')
            addr_line1 = "Standard Delivery Address"
            addr_line2 = "Dhaka, Bangladesh"

        bill_to_content = [
            Paragraph("BILLED & SHIPPED TO:", section_heading),
            Spacer(1, 4),
            Paragraph(f"<b>{customer_name}</b>", body_bold),
            Paragraph(f"Phone: {phone_str}", body_text),
            Paragraph(f"Email: {customer_email}", body_text),
            Paragraph(addr_line1, body_text),
            Paragraph(addr_line2, body_text),
        ]

        # Vector QR Code Widget
        verify_url = f"https://storefront.example.com/orders/{order.id}/verify/"
        qr_widget = qr.QrCodeWidget(verify_url)
        bounds = qr_widget.getBounds()
        w = bounds[2] - bounds[0]
        h = bounds[3] - bounds[1]
        qr_size = 54
        qr_drawing = Drawing(qr_size, qr_size, transform=[qr_size/w, 0, 0, qr_size/h, 0, 0])
        qr_drawing.add(qr_widget)

        order_summary_content = [
            Paragraph("ORDER & PAYMENT AUDIT:", section_heading),
            Spacer(1, 4),
            Paragraph(f"<b>Order ID:</b> #{order.id}", body_text),
            Paragraph(f"<b>Order Status:</b> {order.status}", body_text),
            Paragraph(f"<b>Payment Gateway:</b> {order.payment_method}", body_text),
            Paragraph(f"<b>Trx ID:</b> {order.transaction_id or 'N/A'}", body_text),
        ]

        meta_table = Table(
            [[bill_to_content, order_summary_content, qr_drawing]],
            colWidths=[240, 220, 63],
        )
        meta_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F8FAFC')),
            ('BOX', (0, 0), (-1, -1), 0.5, colors.HexColor('#E2E8F0')),
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('LEFTPADDING', (0, 0), (-1, -1), 10),
            ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ]))
        elements.append(meta_table)
        elements.append(Spacer(1, 16))

        # ── 3. Sub-Orders & Itemized Line Items ──
        sub_orders = list(order.sub_orders.select_related('vendor').prefetch_related('items', 'items__product', 'items__variant'))
        
        item_counter = 1
        for sub in sub_orders:
            vendor = sub.vendor
            vendor_bin = f"BIN-{vendor.id:09d}"
            
            # Sub-Order Vendor Header
            vendor_header_text = (
                f"<b>Sold by:</b> {vendor.store_name} &nbsp;|&nbsp; "
                f"<b>Merchant BIN:</b> {vendor_bin} &nbsp;|&nbsp; "
                f"<b>Sub-Order #:</b> {sub.id} ({sub.fulfillment_type})"
            )
            sub_header = Table(
                [[Paragraph(vendor_header_text, body_bold)]],
                colWidths=[523],
            )
            sub_header.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#EEF2F6')),
                ('BOX', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
                ('TOPPADDING', (0, 0), (-1, -1), 5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
            ]))
            
            # Table of Items
            table_data = [
                [
                    Paragraph("#", table_hdr),
                    Paragraph("Item & Description", table_hdr),
                    Paragraph("Variant / SKU", table_hdr),
                    Paragraph("Unit Price", ParagraphStyle('THRight', parent=table_hdr, alignment=2)),
                    Paragraph("Qty", ParagraphStyle('THCenter', parent=table_hdr, alignment=1)),
                    Paragraph("Tax", ParagraphStyle('THRight', parent=table_hdr, alignment=2)),
                    Paragraph("Total", ParagraphStyle('THRight', parent=table_hdr, alignment=2)),
                ]
            ]
            
            for item in sub.items.all():
                title = item.product_title or (item.product.name if item.product else 'Item')
                variant_desc = item.variant_name or (item.variant.name if item.variant else '')
                sku_str = item.sku or 'N/A'
                var_sku = f"{variant_desc} ({sku_str})" if variant_desc else sku_str
                
                unit_price = item.unit_price or Decimal('0.00')
                tax_val = item.tax or Decimal('0.00')
                line_total = item.total_price if hasattr(item, 'total_price') else (unit_price * item.quantity + tax_val)

                table_data.append([
                    Paragraph(str(item_counter), table_cell),
                    Paragraph(title, table_cell_bold),
                    Paragraph(var_sku, table_cell),
                    Paragraph(f"৳{unit_price:,.2f}", table_cell_right),
                    Paragraph(str(item.quantity), ParagraphStyle('TCCenter', parent=table_cell, alignment=1)),
                    Paragraph(f"৳{tax_val:,.2f}", table_cell_right),
                    Paragraph(f"৳{line_total:,.2f}", ParagraphStyle('TCRightBold', parent=table_cell_bold, alignment=2)),
                ])
                item_counter += 1

            items_table = Table(
                table_data,
                colWidths=[20, 203, 100, 60, 30, 45, 65],
            )
            items_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#F8FAFC')),
                ('BOX', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
                ('INNERGRID', (0, 0), (-1, -1), 0.25, colors.HexColor('#E2E8F0')),
                ('TOPPADDING', (0, 0), (-1, -1), 5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
                ('LEFTPADDING', (0, 0), (-1, -1), 5),
                ('RIGHTPADDING', (0, 0), (-1, -1), 5),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ]))
            
            elements.append(KeepTogether([sub_header, items_table]))
            elements.append(Spacer(1, 10))

        elements.append(Spacer(1, 6))

        # ── 4. Financial Totals & Compliance Notes ──
        subtotal = order.subtotal_amount or Decimal('0.00')
        discount = order.discount_amount or Decimal('0.00')
        wallet_applied = order.wallet_amount_applied or Decimal('0.00')
        grand_total = order.total_amount or Decimal('0.00')
        payable = order.payable_amount

        totals_data = [
            [Paragraph("Items Subtotal:", body_text), Paragraph(f"৳{subtotal:,.2f}", ParagraphStyle('TR1', parent=body_text, alignment=2))],
        ]
        if discount > 0:
            totals_data.append([
                Paragraph("Coupon Discount:", body_text),
                Paragraph(f"- ৳{discount:,.2f}", ParagraphStyle('TR2', parent=body_text, alignment=2, textColor=colors.HexColor('#10B981'))),
            ])
        if wallet_applied > 0:
            totals_data.append([
                Paragraph("Wallet Balance Applied:", body_text),
                Paragraph(f"- ৳{wallet_applied:,.2f}", ParagraphStyle('TR3', parent=body_text, alignment=2, textColor=colors.HexColor('#10B981'))),
            ])
        totals_data.extend([
            [Paragraph("<b>Grand Total:</b>", body_bold), Paragraph(f"<b>৳{grand_total:,.2f}</b>", ParagraphStyle('TR4', parent=body_bold, alignment=2))],
            [
                Paragraph("<b>Net Payable:</b>", ParagraphStyle('PayHdr', parent=body_bold, fontSize=10, textColor=colors.HexColor('#0F172A'))),
                Paragraph(f"<b>৳{payable:,.2f}</b>", ParagraphStyle('PayVal', parent=body_bold, fontSize=10, alignment=2, textColor=colors.HexColor('#0F172A'))),
            ],
        ])

        totals_table = Table(
            totals_data,
            colWidths=[130, 100],
        )
        totals_table.setStyle(TableStyle([
            ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor('#F1F5F9')),
            ('LINEABOVE', (0, -2), (-1, -2), 0.5, colors.HexColor('#CBD5E1')),
            ('LINEABOVE', (0, -1), (-1, -1), 1, colors.HexColor('#0F172A')),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ]))

        notes_content = [
            Paragraph("<b>TERMS & DECLARATION:</b>", section_heading),
            Spacer(1, 3),
            Paragraph("1. This tax invoice is computer-generated and legally valid without a signature.", body_muted),
            Paragraph("2. All applicable Value Added Tax (VAT) is included as per NBR statutory rules.", body_muted),
            Paragraph("3. Products qualify for 7-day return/replacement under Storefront RMA Policy.", body_muted),
            Paragraph("4. Scan the QR code above or verify online at storefront.com.bd/verify.", body_muted),
        ]

        summary_block = Table(
            [[notes_content, totals_table]],
            colWidths=[283, 240],
        )
        summary_block.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))

        elements.append(KeepTogether([summary_block]))

        # Build Document
        doc.build(elements, canvasmaker=NumberedCanvas)
        pdf_bytes = buffer.getvalue()
        buffer.close()
        return pdf_bytes
