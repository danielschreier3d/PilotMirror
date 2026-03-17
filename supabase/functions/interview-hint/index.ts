import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { question, language } = await req.json()
    if (!question) {
      return new Response(JSON.stringify({ error: "Missing question" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    const isGerman = language === "de"
    const systemPrompt = isGerman
      ? "Du bist ein erfahrener Pilotenausbilder und Assessmentcoach. Antworte immer auf Deutsch."
      : "You are an experienced flight instructor and assessment coach. Always respond in English."

    const userPrompt = isGerman
      ? `Gib eine kurze, präzise Musterantwort (2–4 Sätze) auf folgende Interviewfrage für Pilotenanwärter:\n\n"${question}"\n\nDie Antwort soll dem Interviewer helfen, die Aussage des Kandidaten sachlich zu werten. Fachbegriffe sind erwünscht.`
      : `Give a short, precise model answer (2–4 sentences) to the following pilot candidate interview question:\n\n"${question}"\n\nThe answer should help the interviewer factually assess the candidate's response. Technical terms are welcome.`

    const groqResponse = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("GROQ_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        max_tokens: 200,
        temperature: 0.3,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
    })

    const groqData = await groqResponse.json()
    const hint = groqData.choices?.[0]?.message?.content

    if (!hint) {
      const errMsg = groqData.error?.message ?? "No content returned from Groq"
      return new Response(JSON.stringify({ error: errMsg }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    return new Response(JSON.stringify({ hint }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
