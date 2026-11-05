// Deploy with: supabase functions deploy agriwaste-assistant
// Set secret: supabase secrets set OPENAI_API_KEY=...
// Never put an AI provider secret in the browser.
Deno.serve(async (req) => {
  const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: cors });
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return new Response(JSON.stringify({ error: "AI service is not configured by the site administrator." }), { status: 503, headers: { ...cors, "Content-Type": "application/json" } });
  try {
    const { material, language = "en" } = await req.json();
    const allowed = ["Paddy straw","Rice husk","Coconut husk","Banana pseudostem","Sugarcane bagasse","Groundnut shells","Maize stalks","Fruit and vegetable peels"];
    if (!allowed.includes(material)) return new Response(JSON.stringify({ error: "Unsupported material." }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    const prompt = `Give a careful agricultural residue utilization briefing for ${material}. Respond in ${language === "od" ? "Odia" : "English"}. Include: likely uses, basic process overview, quality/safety checks, possible buyer sectors, and limitations. Do not invent market prices, yields, investment figures, or claim guaranteed suitability. Mention that local technical validation is required. Keep it concise and practical for Indian smallholders.`;
    const r = await fetch("https://api.openai.com/v1/responses", { method: "POST", headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" }, body: JSON.stringify({ model: "gpt-4.1-mini", input: prompt, max_output_tokens: 650 }) });
    const data = await r.json();
    if (!r.ok) return new Response(JSON.stringify({ error: "AI provider request failed.", details: data.error?.message }), { status: 502, headers: { ...cors, "Content-Type": "application/json" } });
    const answer = (data.output || []).flatMap((o: any) => o.content || []).filter((c: any) => c.type === "output_text").map((c: any) => c.text).join("\\n");
    return new Response(JSON.stringify({ answer }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) { return new Response(JSON.stringify({ error: "Invalid request." }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } }); }
});
