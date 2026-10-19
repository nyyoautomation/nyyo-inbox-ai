/** On-device inbox triage — no API key. Keyword + pattern extractor. */
(function (g) {
  const RULES = [
    { label: "complaint", score: 3, words: ["refund", "angry", "unacceptable", "lawyer", "complaint", "terrible", "never again", "réclamation", "remboursement"] },
    { label: "support", score: 2, words: ["not working", "bug", "error", "help", "issue", "broken", "can't login", "support", "aide"] },
    { label: "quote", score: 2, words: ["quote", "pricing", "how much", "proposal", "devis", "budget", "interested in"] },
    { label: "billing", score: 2, words: ["invoice", "payment", "charged", "receipt", "facture", "carte"] },
    { label: "general", score: 1, words: ["thanks", "hello", "question", "info"] },
  ];

  function classify(text) {
    const low = (text || "").toLowerCase();
    let best = { label: "general", score: 0 };
    for (const r of RULES) {
      let s = 0;
      for (const w of r.words) if (low.includes(w)) s += r.score;
      if (s > best.score) best = { label: r.label, score: s };
    }
    return best.label;
  }

  function extract(text) {
    const fields = {};
    const email = text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
    if (email) fields.email = email[0];
    const order = text.match(/\b(?:order|commande)\s*#?\s*([A-Z0-9-]{4,})/i);
    if (order) fields.order_id = order[1];
    const money = text.match(/(?:\$|\u20ac|USD|EUR)\s*([0-9]+(?:[.,][0-9]{2})?)|([0-9]+(?:[.,][0-9]{2})?)\s*(?:\$|\u20ac|USD|EUR)/i);
    if (money) fields.amount = (money[1] || money[2] || "").replace(",", ".");
    const date = text.match(/\b(\d{4}-\d{2}-\d{2}|\d{1,2}[\/.-]\d{1,2}[\/.-]\d{2,4})\b/);
    if (date) fields.date = date[1];
    const product = text.match(/\b(?:product|item|article|plan)\s*[:\-]?\s*([A-Za-z0-9][A-Za-z0-9 \-]{2,40})/i);
    if (product) fields.product = product[1].trim();
    const name = text.match(/(?:^|\n)\s*(?:regards|thanks|cordialement|—|-)?\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s*$/m);
    if (name) fields.signoff = name[1];
    return fields;
  }

  const REPLIES = {
    complaint: "Hi — sorry about this. I've flagged your case as priority. Please confirm order id and preferred refund or replacement. — Support",
    support: "Hi — thanks for the details. We're looking into it. Meanwhile try clearing cache / resetting the password link. — Support",
    quote: "Hi — thanks for your interest. We can share a fixed-scope quote within 24h if you send goal, deadline and budget. — Nyyo Automation",
    billing: "Hi — we received your billing note. Our finance queue will check the charge and reply within one business day. — Billing",
    general: "Hi — thanks for writing. We've logged your message and will get back shortly. — Support",
  };

  function analyze(text) {
    const label = classify(text);
    const fields = extract(text);
    return {
      label,
      confidence: label === "general" ? "low" : "medium",
      fields,
      draft_reply: REPLIES[label] || REPLIES.general,
      engine: "on-device rules (no API key)",
    };
  }

  g.NyyoInboxAI = { analyze, classify, extract };
})(typeof window !== "undefined" ? window : globalThis);
