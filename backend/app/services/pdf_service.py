import io
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch


class ClinicalPDFReportGenerator:
    """Generates a clean, professional, non-diagnostic one-page doctor consultation summary."""

    @staticmethod
    def generate_doctor_report(
        session_id: str,
        confirmed_symptoms: List[str],
        cycle_analytics: Dict[str, Any],
        knowledge_refs: List[Dict[str, Any]],
        patient_notes: Optional[str] = None
    ) -> bytes:
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=36,
            leftMargin=36,
            topMargin=36,
            bottomMargin=36
        )

        styles = getSampleStyleSheet()
        
        # Custom palette: Warm ivory/sage green/charcoal
        charcoal = colors.HexColor("#2D312E")
        sage_green = colors.HexColor("#4A6B53")
        muted_sage = colors.HexColor("#EBF2ED")
        accent_lavender = colors.HexColor("#7E6390")
        light_border = colors.HexColor("#D8E2DC")

        title_style = ParagraphStyle(
            'DocTitle',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=16,
            leading=18,
            textColor=sage_green,
        )
        subtitle_style = ParagraphStyle(
            'DocSubtitle',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=9,
            leading=11,
            textColor=charcoal,
        )
        section_heading = ParagraphStyle(
            'SectionHead',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=10,
            leading=13,
            textColor=sage_green,
        )
        body_style = ParagraphStyle(
            'Body',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8.5,
            leading=11,
            textColor=charcoal,
        )
        disclaimer_style = ParagraphStyle(
            'Disclaimer',
            parent=styles['Normal'],
            fontName='Helvetica-Oblique',
            fontSize=7.5,
            leading=9.5,
            textColor=colors.HexColor("#666666"),
        )

        elements = []

        # 1. Header & Title
        elements.append(Paragraph("Sakhi | Doctor Consultation Summary", title_style))
        elements.append(Spacer(1, 2))
        elements.append(Paragraph(
            f"Generated: {datetime.now(timezone.utc).strftime('%d %B %Y')} | Session ID: {session_id} | Purpose: Patient Self-Advocacy & Clinical Discussion",
            subtitle_style
        ))
        elements.append(Spacer(1, 6))
        elements.append(HRFlowable(width="100%", thickness=1, color=sage_green, spaceBefore=1, spaceAfter=6))

        # 2. Symptoms Overview Card
        elements.append(Paragraph("1. PATIENT-CONFIRMED SYMPTOMS & OBSERVATIONS", section_heading))
        elements.append(Spacer(1, 3))
        
        sym_text = ", ".join(confirmed_symptoms) if confirmed_symptoms else "No specific symptoms logged."
        if patient_notes:
            sym_text += f"<br/><b>Patient Notes:</b> {patient_notes}"

        sym_table = Table(
            [[Paragraph(f"<b>Reported Concerns:</b> {sym_text}", body_style)]],
            colWidths=[540]
        )
        sym_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), muted_sage),
            ('BOX', (0, 0), (-1, -1), 0.5, light_border),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        ]))
        elements.append(sym_table)
        elements.append(Spacer(1, 8))

        # 3. Menstrual Cycle Analytics & Timeline
        elements.append(Paragraph("2. MENSTRUAL CYCLE HISTORY & LONGITUDINAL INTERVALS (6 MONTHS)", section_heading))
        elements.append(Spacer(1, 3))

        history = cycle_analytics.get("history", [])
        avg_gap = cycle_analytics.get("average_gap_days", "N/A")
        min_gap = cycle_analytics.get("min_gap_days", "N/A")
        max_gap = cycle_analytics.get("max_gap_days", "N/A")
        sd_gap = cycle_analytics.get("variation_sd", "N/A")

        summary_p = (
            f"<b>Total Cycles Logged:</b> {len(history)} | "
            f"<b>Mean Cycle Length:</b> {avg_gap} days | "
            f"<b>Range:</b> {min_gap}–{max_gap} days | "
            f"<b>Standard Deviation:</b> {sd_gap} days"
        )
        elements.append(Paragraph(summary_p, body_style))
        elements.append(Spacer(1, 3))

        # Cycle History Table
        table_rows = [["Recorded Period Start", "Calculated Interval (Gap)", "Reported Flow", "Type"]]
        for item in history[:5]:  # Display last 5 cycles
            gap = f"{item.get('cycle_gap_days')} days" if item.get('cycle_gap_days') else "Baseline (first entry)"
            tag = "Demo Seed" if item.get("is_demo") else "User Recorded"
            table_rows.append([
                item.get("period_start_date", "-"),
                gap,
                str(item.get("flow_intensity", "-")).title(),
                tag
            ])

        if len(table_rows) == 1:
            table_rows.append(["No cycle entries recorded.", "-", "-", "-"])

        c_table = Table(table_rows, colWidths=[135, 145, 130, 130])
        c_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), sage_green),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, -1), 7.5),
            ('GRID', (0, 0), (-1, -1), 0.5, light_border),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ]))
        elements.append(c_table)
        elements.append(Spacer(1, 8))

        # 4. Clinical Evidence & References
        elements.append(Paragraph("3. CLINICAL EVIDENCE REFERENCES (ROTTERDAM GUIDELINES)", section_heading))
        elements.append(Spacer(1, 3))

        ref_items = []
        for ref in knowledge_refs[:3]:
            ref_items.append(
                f"• <b>{ref.get('title')}</b> — <i>{ref.get('source_org')}</i>: {ref.get('concept')} "
                f"(<font color='#4A6B53'><u>{ref.get('source_url')}</u></font>)"
            )
        if not ref_items:
            ref_items.append("• Rotterdam PCOS Guidelines (2023) — Infrequent cycles or hyperandrogenism warrant clinical assessment.")

        elements.append(Paragraph("<br/>".join(ref_items), body_style))
        elements.append(Spacer(1, 8))

        # 5. Questions for Healthcare Provider
        elements.append(Paragraph("4. SUGGESTED QUESTIONS FOR YOUR HEALTHCARE PROVIDER", section_heading))
        elements.append(Spacer(1, 3))
        questions = [
            "1. Given my cycle intervals and symptoms, would you recommend testing fasting insulin, androgen levels, or thyroid (TSH)?",
            "2. Would a pelvic ultrasound be beneficial to assess ovarian morphology?",
            "3. Are there lifestyle or nutritional guidelines appropriate for my symptom pattern?",
            "4. What red flag symptoms should prompt urgent reassessment?"
        ]
        elements.append(Paragraph("<br/>".join(questions), body_style))
        elements.append(Spacer(1, 8))

        # 6. Non-Diagnostic Disclaimer Box
        elements.append(HRFlowable(width="100%", thickness=0.5, color=light_border, spaceBefore=2, spaceAfter=4))
        elements.append(Paragraph(
            "<b>IMPORTANT CLINICAL DISCLAIMER:</b> Sakhi is an informational companion designed to help women track observations and prepare for conversations with healthcare professionals. This document does NOT constitute a medical diagnosis, clinical evaluation, or prescription. A diagnosis of PCOS requires formal clinical history, laboratory testing, and pelvic imaging conducted by a licensed physician.",
            disclaimer_style
        ))

        doc.build(elements)
        buffer.seek(0)
        return buffer.getvalue()

