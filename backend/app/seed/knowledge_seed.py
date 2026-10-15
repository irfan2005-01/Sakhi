from typing import List, Dict, Any

CLINICAL_KNOWLEDGE_ENTRIES: List[Dict[str, Any]] = [
    {
        "id": "kb-cycle-irregularity",
        "title": "Irregular or Missed Menstrual Cycles (Oligomenorrhea)",
        "topic": "Menstrual Patterns",
        "concept": "Ovulatory dysfunction characterized by cycle length > 35 days or < 8 cycles per year",
        "plain_explanation": "Irregular periods mean ovulation is infrequent or unpredictable. In PCOS, hormonal imbalances prevent follicles from maturing and releasing an egg every month.",
        "vernacular_terms": ["period late", "mahina late", "irregual periods", "chadh ke aana", "date aage piche hona", "bleeding gap"],
        "source_org": "Monash University / International PCOS Guideline 2023",
        "source_url": "https://www.monash.edu/medicine/sphpm/m-erec/international-pcos-guideline",
        "evidence_excerpt": "Irregular menstrual cycles are defined as: > 35 days or < 21 days or < 8 cycles per year after gynecological maturity. Ovulatory dysfunction is one of three Rotterdam diagnostic criteria.",
        "review_status": "reviewed",
        "review_date": "2024-01-15",
        "is_demo": False,
    },
    {
        "id": "kb-hyperandrogenism",
        "title": "Hirsutism and Elevated Androgens",
        "topic": "Hormonal Symptoms",
        "concept": "Clinical and biochemical hyperandrogenism (excess male-pattern hormones like testosterone)",
        "plain_explanation": "Higher levels of androgen hormones can lead to coarse hair growth on the chin, chest, or stomach, as well as stubborn acne and scalp hair thinning.",
        "vernacular_terms": ["facial hair", "chin baal", "unwanted hair", "chehre par baal", "acne", "pimples", "hair fall"],
        "source_org": "American College of Obstetricians and Gynecologists (ACOG)",
        "source_url": "https://www.acog.org/womens-health/faqs/polycystic-ovary-syndrome-pcos",
        "evidence_excerpt": "Excess androgen hormones can cause excess facial and body hair (hirsutism), severe adult acne, and male-pattern baldness (androgenic alopecia).",
        "review_status": "reviewed",
        "review_date": "2024-02-10",
        "is_demo": False,
    },
    {
        "id": "kb-insulin-resistance",
        "title": "Insulin Resistance and Metabolic Changes",
        "topic": "Metabolic Health",
        "concept": "Impaired cellular glucose uptake leading to compensatory hyperinsulinemia",
        "plain_explanation": "Insulin resistance means cells do not respond effectively to insulin. This triggers higher insulin production, which can stimulate ovaries to produce more androgens and cause weight gain or dark velvety skin patches.",
        "vernacular_terms": ["weight gain", "wazan badhna", "motaapa", "sugar craving", "dark neck", "gardan kali hona", "fatigue"],
        "source_org": "National Institute of Child Health and Human Development (NIH/NICHD)",
        "source_url": "https://www.nichd.nih.gov/health/topics/pcos/conditioninfo",
        "evidence_excerpt": "Up to 70% of women with PCOS have insulin resistance. Hyperinsulinemia stimulates ovarian theca cells to synthesize androgens and reduces sex hormone-binding globulin (SHBG).",
        "review_status": "reviewed",
        "review_date": "2024-02-18",
        "is_demo": False,
    },
    {
        "id": "kb-polycystic-ovaries-imaging",
        "title": "Polycystic Ovarian Morphology on Ultrasound",
        "topic": "Clinical Diagnostics",
        "concept": "Ultrasonographic appearance of increased follicle count per ovary (PCOM)",
        "plain_explanation": "An ultrasound might show small, undeveloped fluid-filled follicles ('cysts') arranged like a string of pearls. However, having cysts alone does not mean PCOS, and some women with PCOS do not have them.",
        "vernacular_terms": ["ultrasound report", "sonography", "ovary me cyst", "paani ki gath", "follicles"],
        "source_org": "Endocrine Society Clinical Practice Guidelines",
        "source_url": "https://www.endocrine.org/clinical-practice-guidelines/polycystic-ovary-syndrome",
        "evidence_excerpt": "Polycystic ovarian morphology is defined as >= 20 follicles per ovary and/or ovarian volume >= 10 mL using high-frequency transvaginal ultrasound in adults.",
        "review_status": "reviewed",
        "review_date": "2024-03-01",
        "is_demo": False,
    },
    {
        "id": "kb-rotterdam-criteria",
        "title": "Rotterdam Consensus Diagnostic Framework",
        "topic": "Clinical Assessment",
        "concept": "Formal diagnostic requirement of at least 2 of 3 features after excluding other etiologies",
        "plain_explanation": "Doctors assess PCOS using the Rotterdam Criteria. A diagnosis requires at least two of three criteria: irregular periods, high androgen levels or physical signs of excess hair/acne, and polycystic ovaries on ultrasound. Other conditions like thyroid disorders must first be ruled out.",
        "vernacular_terms": ["pcos test", "diagnosis criteria", "doctor kaise check karta hai", "kya mujhe pcos hai"],
        "source_org": "European Society of Human Reproduction and Embryology (ESHRE) / ASRM",
        "source_url": "https://www.eshre.eu/Guidelines-and-Legal/Guidelines/Polycystic-Ovary-Syndrome",
        "evidence_excerpt": "PCOS diagnosis requires presence of >= 2 of: 1) Oligo- or anovulation, 2) Clinical and/or biochemical hyperandrogenism, 3) Polycystic ovaries on ultrasound, with exclusion of related disorders (CAH, hyperprolactinemia, thyroid disease).",
        "review_status": "reviewed",
        "review_date": "2024-01-20",
        "is_demo": False,
    },
    {
        "id": "kb-urgent-pelvic-pain",
        "title": "Acute Pelvic Pain & Red Flag Symptoms",
        "topic": "Emergency Care Navigation",
        "concept": "Urgent differential diagnoses including ovarian torsion, ectopic pregnancy, or ruptured ovarian cyst",
        "plain_explanation": "Severe sudden pelvic pain, intense cramping accompanied by dizziness or vomiting, or bleeding so heavy it soaks through two pads per hour are medical emergencies that require immediate hospital assessment.",
        "vernacular_terms": ["severe pet dard", "chakkkar aana", "behosh hona", "khoon ruk nahi raha", "bhayanak dard", "bleeding soaking pads"],
        "source_org": "NHS (National Health Service, UK)",
        "source_url": "https://www.nhs.uk/conditions/pelvic-pain/",
        "evidence_excerpt": "Sudden, severe pelvic pain with fever, fainting, or abnormal bleeding can indicate ovarian torsion or rupture, requiring immediate emergency medical evaluation.",
        "review_status": "reviewed",
        "review_date": "2024-02-05",
        "is_demo": False,
    },
    {
        "id": "kb-demo-diet-lifestyle",
        "title": "Nutrition and Low-Glycemic Dietary Patterns (Demo Reference)",
        "topic": "Lifestyle Navigation",
        "concept": "Dietary support focusing on glycemic stability and regular physical activity",
        "plain_explanation": "Balanced meals with fiber-rich vegetables, whole grains, and protein help stabilize blood sugar levels and manage energy dips associated with metabolic sensitivity.",
        "vernacular_terms": ["khana pina", "diet plan", "pcos food", "kya khaye", "meetha craving"],
        "source_org": "Academy of Nutrition and Dietetics [Demo Seed Data - Needs Clinical Review]",
        "source_url": "https://www.eatright.org/health/wellness/reproductive-health/pcos-and-diet",
        "evidence_excerpt": "A low-glycemic index dietary pattern combined with regular aerobic activity improves insulin sensitivity in individuals with ovulatory disorders.",
        "review_status": "needs_clinical_review",
        "review_date": "2024-04-01",
        "is_demo": True,
    }
]


async def seed_knowledge_base(db_manager):
    """Seed the clinical knowledge base if empty."""
    collection = db_manager.knowledge_collection
    count = await collection.count_documents({})
    if count == 0:
        await collection.insert_many(CLINICAL_KNOWLEDGE_ENTRIES)
        return len(CLINICAL_KNOWLEDGE_ENTRIES)
    return count

