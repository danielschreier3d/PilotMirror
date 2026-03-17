import type { Question, FlightLicense } from "./types";

// ─── Survey Questions (ported from Question.swift) ────────────────────────────

export const SURVEY_QUESTIONS: Question[] = [
  // Section 1 — Persönlichkeit
  {
    id: "q1", type: "traitSelection",
    text: "Welche Eigenschaften beschreiben diese Person? Alle zutreffenden auswählen.",
    textEN: "Which words describe this person? Select all that apply.",
    textSelf: "Welche Eigenschaften beschreiben dich am besten? Alle zutreffenden auswählen.",
    textSelfEN: "Which words describe you best? Select all that apply.",
    options: ["ruhig","analytisch","strukturiert","selbstsicher","teamorientiert",
              "kommunikativ","verantwortungsbewusst","belastbar","empathisch",
              "führungsstark","introvertiert","dominant","impulsiv",
              "konfliktscheu","ungeduldig","unorganisiert"],
    optionsEN: ["calm","analytical","structured","confident","team-oriented",
                "communicative","responsible","resilient","empathetic",
                "strong leader","introverted","dominant","impulsive",
                "conflict-avoidant","impatient","disorganised"],
    section: 1, sectionTitle: "Persönlichkeit", sectionTitleEN: "Personality",
  },

  // Section 2 — Entscheidungsstil
  {
    id: "q2", type: "forcedChoice",
    text: "Diese Person entscheidet eher:",
    textEN: "This person tends to decide:",
    textSelf: "Du entscheidest eher:",
    textSelfEN: "You tend to decide:",
    options: ["Schnell und intuitiv","Nach sorgfältiger Analyse"],
    optionsEN: ["Quickly and intuitively","After careful analysis"],
    section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style",
  },
  {
    id: "q3", type: "forcedChoice",
    text: "In Gruppen tendiert diese Person dazu:",
    textEN: "In groups, this person tends to:",
    textSelf: "In Gruppen tendierst du dazu:",
    textSelfEN: "In groups, you tend to:",
    options: ["häufig die Führung zu übernehmen","aktiv Ideen einzubringen","zunächst zu beobachten und später zu sprechen"],
    optionsEN: ["take the lead frequently","actively contribute ideas","observe first and speak later"],
    section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style",
  },
  {
    id: "q4", type: "forcedChoice",
    text: "Wenn etwas schiefläuft, reagiert diese Person:",
    textEN: "When something goes wrong, this person reacts:",
    textSelf: "Wenn etwas schiefläuft, reagierst du:",
    textSelfEN: "When something goes wrong, you react:",
    options: ["Ruhig & lösungsorientiert","Gestresst aber funktional","Emotional/frustriert"],
    optionsEN: ["Calm and solution-focused","Stressed but functional","Emotionally/frustrated"],
    section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style",
  },
  {
    id: "q4b", type: "forcedChoice",
    text: "Wenn Meinungsverschiedenheiten entstehen, reagiert diese Person eher:",
    textEN: "When disagreements arise, this person tends to:",
    textSelf: "Wenn Meinungsverschiedenheiten entstehen, reagierst du eher:",
    textSelfEN: "When disagreements arise, you tend to:",
    options: ["Konflikte vermeiden","Zwischen den Positionen vermitteln","Die eigene Position aktiv vertreten"],
    optionsEN: ["Avoid conflict","Mediate between positions","Actively defend their own position"],
    section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style",
  },

  // Section 3 — Bewertungen
  {
    id: "q5", type: "ratingScale",
    text: "Teamfähigkeit", textEN: "Teamwork",
    textSelf: "Teamfähigkeit", textSelfEN: "Teamwork",
    scaleMin: 1, scaleMax: 5,
    section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings",
  },
  {
    id: "q6", type: "ratingScale",
    text: "Stressresistenz", textEN: "Stress Resistance",
    textSelf: "Stressresistenz", textSelfEN: "Stress Resistance",
    scaleMin: 1, scaleMax: 5,
    section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings",
  },
  {
    id: "q7", type: "ratingScale",
    text: "Verantwortungsbewusstsein", textEN: "Responsibility",
    textSelf: "Verantwortungsbewusstsein", textSelfEN: "Responsibility",
    scaleMin: 1, scaleMax: 5,
    section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings",
  },
  {
    id: "q8", type: "ratingScale",
    text: "Kommunikation", textEN: "Communication",
    textSelf: "Kommunikation", textSelfEN: "Communication",
    scaleMin: 1, scaleMax: 5,
    section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings",
  },
  {
    id: "q9", type: "ratingScale",
    text: "Zuverlässigkeit", textEN: "Reliability",
    textSelf: "Zuverlässigkeit", textSelfEN: "Reliability",
    scaleMin: 1, scaleMax: 5,
    section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings",
  },
  {
    id: "q10_org", type: "ratingScale",
    text: "Wie strukturiert arbeitet diese Person?",
    textEN: "How organised is this person in their work?",
    textSelf: "Wie strukturiert arbeitest du?",
    textSelfEN: "How organised are you in your work?",
    scaleMin: 1, scaleMax: 5,
    section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings",
  },

  // Section 4 — Stärken
  {
    id: "q10", type: "openText",
    text: "Was ist eine der größten Stärken von dieser Person?",
    textEN: "What is one of this person's greatest strengths?",
    textSelf: "Was ist eine deiner größten Stärken?",
    textSelfEN: "What is one of your greatest strengths?",
    placeholder: "z.B. bleibt in stressigen Situationen ruhig und strukturiert…",
    placeholderEN: "e.g. stays calm and structured in stressful situations…",
    section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths",
  },
  {
    id: "q11", type: "openText",
    text: "Wofür wird diese Person von anderen besonders geschätzt?",
    textEN: "What is this person particularly appreciated for by others?",
    textSelf: "Wofür wirst du von anderen besonders geschätzt?",
    textSelfEN: "What are you particularly appreciated for by others?",
    placeholder: "z.B. ist immer gut vorbereitet, motiviert andere…",
    placeholderEN: "e.g. always well-prepared, motivates others…",
    section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths",
  },
  {
    id: "q12", type: "openText",
    text: "In welchen Situationen hilft diese Person einer Gruppe besonders?",
    textEN: "In which situations does this person help a group most?",
    textSelf: "In welchen Situationen hilfst du einer Gruppe besonders?",
    textSelfEN: "In which situations do you help a group most?",
    placeholder: "z.B. in Konfliktsituationen, bei der Planung, unter Druck…",
    placeholderEN: "e.g. in conflict situations, during planning, under pressure…",
    section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths",
  },

  // Section 5 — Schwächen
  {
    id: "q13", type: "openText",
    text: "Wo hat diese Person im Alltag Entwicklungspotenzial?",
    textEN: "Where does this person have room to develop in everyday life?",
    textSelf: "Wo hast du im Alltag Entwicklungspotenzial?",
    textSelfEN: "Where do you have room to develop in everyday life?",
    placeholder: "z.B. könnte strukturierter planen, mehr auf andere eingehen…",
    placeholderEN: "e.g. could plan more systematically, be more attentive to others…",
    section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses",
  },
  {
    id: "q14", type: "openText",
    text: "Gibt es Verhaltensweisen von dieser Person, die manchmal schwierig sein können?",
    textEN: "Are there behaviours of this person that can sometimes be difficult?",
    textSelf: "Gibt es Verhaltensweisen bei dir, die manchmal schwierig sein können?",
    textSelfEN: "Are there behaviours of yours that can sometimes be difficult?",
    placeholder: "z.B. reagiert manchmal ungeduldig, wenn Dinge nicht nach Plan laufen…",
    placeholderEN: "e.g. sometimes reacts impatiently when things don't go as planned…",
    section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses",
  },
  {
    id: "q15", type: "openText",
    text: "Welches Verhalten von dieser Person kann in Gruppen gelegentlich problematisch sein?",
    textEN: "Which of this person's behaviours can occasionally be problematic in groups?",
    textSelf: "Welches deiner eigenen Verhaltensweisen kann in Gruppen gelegentlich problematisch sein?",
    textSelfEN: "Which of your own behaviours can occasionally be problematic in groups?",
    placeholder: "z.B. übernimmt zu schnell das Wort, hört nicht aktiv zu…",
    placeholderEN: "e.g. takes the floor too quickly, doesn't listen actively…",
    section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses",
  },

  // Section 6 — Verhalten & Außenwirkung
  {
    id: "q16", type: "openText",
    text: "Gibt es negative Verhaltensweisen im Alltag, die dieser Person wahrscheinlich nicht bewusst sind?",
    textEN: "Are there negative everyday behaviors this person is probably unaware of?",
    textSelf: "Gibt es Verhaltensweisen bei dir, die dir selbst vielleicht nicht bewusst sind?",
    textSelfEN: "Are there behaviors in yourself that you may not be aware of?",
    placeholder: "z.B. unterbricht andere im Gespräch, reagiert defensiv auf Kritik…",
    placeholderEN: "e.g. interrupts others, reacts defensively to criticism…",
    section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception",
  },
  {
    id: "q17", type: "openText",
    text: "Wie reagiert diese Person auf Kritik oder eigene Fehler?",
    textEN: "How does this person react to criticism or their own mistakes?",
    textSelf: "Wie reagierst du, wenn du kritisiert wirst oder Fehler machst?",
    textSelfEN: "How do you react when you are criticised or make a mistake?",
    placeholder: "z.B. nimmt Feedback gut an / wird defensiv / zieht sich zurück…",
    placeholderEN: "e.g. takes feedback well / becomes defensive / withdraws…",
    section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception",
  },
  {
    id: "q18", type: "openText",
    text: "Wenn diese Person an einem anspruchsvollen Auswahlverfahren teilnimmt – welches Verhalten könnte besonders hilfreich oder hinderlich sein?",
    textEN: "If this person were to take part in a demanding selection process – which behaviours could help or hinder them the most?",
    textSelf: "Wenn du an einem anspruchsvollen Auswahlverfahren teilnimmst – welches deiner Verhaltensweisen könnte dir besonders helfen oder im Weg stehen?",
    textSelfEN: "If you were to take part in a demanding selection process – which of your behaviours could help or hinder you the most?",
    placeholder: "z.B. wirkt in unbekannten Gruppen zunächst distanziert, obwohl ein starker Teamplayer…",
    placeholderEN: "e.g. initially appears distant in new groups, though a strong team player…",
    section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception",
  },
];

export function getLicenseSpecificQuestions(licenses: FlightLicense[]): Question[] {
  const result: Question[] = [];
  const sec = 7;
  const titleDE = "Fliegerfahrung";
  const titleEN = "Flying Experience";

  if (licenses.includes("PPL") || licenses.includes("LAPL") || licenses.includes("TMG")) {
    result.push(
      { id: "ql1", type: "openText",
        text: "Wie viele Flugstunden hast du bisher absolviert und auf welchen Mustern?",
        textEN: "How many flight hours have you completed and on which aircraft types?",
        textSelf: "Wie viele Flugstunden hast du bisher absolviert und auf welchen Mustern?",
        textSelfEN: "How many flight hours have you completed and on which aircraft types?",
        placeholder: "z.B. 90 Stunden auf C172, 15 Stunden auf DR400…",
        placeholderEN: "e.g. 90 hours on C172, 15 hours on DR400…",
        section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN },
      { id: "ql2", type: "openText",
        text: "Wie bereitest du einen Überlandflug vor? (z.B. PLOG, Wetter, NOTAM, Flugplan)",
        textEN: "How do you prepare a cross-country flight? (e.g. PLOG, weather, NOTAM, flight plan)",
        textSelf: "Wie bereitest du einen Überlandflug vor? (z.B. PLOG, Wetter, NOTAM, Flugplan)",
        textSelfEN: "How do you prepare a cross-country flight? (e.g. PLOG, weather, NOTAM, flight plan)",
        placeholder: "Beschreibe deinen typischen Vorbereitungsprozess…",
        placeholderEN: "Describe your typical preparation process…",
        section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN },
      { id: "ql3", type: "openText",
        text: "Beschreibe eine herausfordernde Situation im Cockpit und wie du damit umgegangen bist.",
        textEN: "Describe a challenging situation in the cockpit and how you handled it.",
        textSelf: "Beschreibe eine herausfordernde Situation im Cockpit und wie du damit umgegangen bist.",
        textSelfEN: "Describe a challenging situation in the cockpit and how you handled it.",
        placeholder: "z.B. unerwartetes Wetter, technisches Problem, schwieriger Anflug…",
        placeholderEN: "e.g. unexpected weather, technical issue, difficult approach…",
        section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN },
      { id: "ql4", type: "openText",
        text: "Was verstehst du unter CRM (Crew Resource Management) und wie lebst du es?",
        textEN: "What do you understand by CRM (Crew Resource Management) and how do you apply it?",
        textSelf: "Was verstehst du unter CRM (Crew Resource Management) und wie lebst du es?",
        textSelfEN: "What do you understand by CRM (Crew Resource Management) and how do you apply it?",
        placeholder: "z.B. offene Kommunikation, gegenseitige Überwachung, klare Aufgabenverteilung…",
        placeholderEN: "e.g. open communication, mutual monitoring, clear task allocation…",
        section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN }
    );
  }
  if (licenses.includes("UL")) {
    result.push(
      { id: "ql_ul1", type: "openText",
        text: "Welche Besonderheiten müssen UL-Piloten bei der Flugplanung beachten?",
        textEN: "What special considerations must ultralight pilots keep in mind when flight planning?",
        textSelf: "Welche Besonderheiten müssen UL-Piloten bei der Flugplanung beachten?",
        textSelfEN: "What special considerations must ultralight pilots keep in mind when flight planning?",
        placeholder: "z.B. Windlimits, Luftraum, Beschränkungen…",
        placeholderEN: "e.g. wind limits, airspace, restrictions…",
        section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN }
    );
  }
  if (licenses.includes("Paramotor")) {
    result.push(
      { id: "ql_pm1", type: "openText",
        text: "Welche Wetterbedingungen prüfst du vor einem Paramotorflug?",
        textEN: "Which weather conditions do you check before a paramotor flight?",
        textSelf: "Welche Wetterbedingungen prüfst du vor einem Paramotorflug?",
        textSelfEN: "Which weather conditions do you check before a paramotor flight?",
        placeholder: "z.B. Wind, Thermik, Sicht, Niederschlag…",
        placeholderEN: "e.g. wind, thermals, visibility, precipitation…",
        section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN }
    );
  }
  if (licenses.includes("Other")) {
    result.push(
      { id: "ql_oth1", type: "openText",
        text: "Beschreibe deine bisherige Flugerfahrung und welche Lektionen du daraus mitgenommen hast.",
        textEN: "Describe your flying experience so far and what lessons you have taken from it.",
        textSelf: "Beschreibe deine bisherige Flugerfahrung und welche Lektionen du daraus mitgenommen hast.",
        textSelfEN: "Describe your flying experience so far and what lessons you have taken from it.",
        placeholder: "z.B. Art der Lizenz, Erfahrungsbereich, wichtigste Lernerfahrungen…",
        placeholderEN: "e.g. type of licence, experience area, key learning experiences…",
        section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN }
    );
  }
  return result;
}
