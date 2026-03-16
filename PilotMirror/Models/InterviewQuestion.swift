import Foundation

// MARK: - InterviewCategory

enum InterviewCategory: String, CaseIterable {
    case math        = "Kopfrechnen"
    case physics     = "Physik & Technik"
    case navigation  = "Navigation & Wetter"
    case aviation    = "Luftfahrtkunde"
    case english     = "Aviation English"
    case spatial     = "Räumliches Denken"
    case personality = "Motivation & Persönlichkeit"
    case judgment    = "Situatives Urteil"

    var showsAnswer: Bool { self == .math || self == .spatial || self == .english }

    var icon: String {
        switch self {
        case .math:        return "function"
        case .physics:     return "atom"
        case .navigation:  return "map.fill"
        case .aviation:    return "airplane"
        case .english:     return "globe"
        case .spatial:     return "cube.fill"
        case .personality: return "person.fill"
        case .judgment:    return "exclamationmark.triangle.fill"
        }
    }

    var labelEN: String {
        switch self {
        case .math:        return "Mental Math"
        case .physics:     return "Physics & Tech"
        case .navigation:  return "Navigation & Weather"
        case .aviation:    return "Aviation Knowledge"
        case .english:     return "Aviation English"
        case .spatial:     return "Spatial Reasoning"
        case .personality: return "Motivation & Personality"
        case .judgment:    return "Situational Judgment"
        }
    }
}

// MARK: - SessionSize

enum SessionSize: CaseIterable {
    case small   // ~8 questions
    case medium  // ~16 questions
    case large   // ~24 questions

    var questionsPerCategory: Int {
        switch self {
        case .small:  return 1
        case .medium: return 2
        case .large:  return 3
        }
    }

    var labelDE: String {
        switch self {
        case .small:  return "Klein"
        case .medium: return "Mittel"
        case .large:  return "Groß"
        }
    }

    var labelEN: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }

    var countLabel: String {
        switch self {
        case .small:  return "~8"
        case .medium: return "~16"
        case .large:  return "~24"
        }
    }

    var descriptionDE: String {
        switch self {
        case .small:  return "1 Frage pro Kategorie"
        case .medium: return "2 Fragen pro Kategorie"
        case .large:  return "3 Fragen pro Kategorie"
        }
    }

    var descriptionEN: String {
        switch self {
        case .small:  return "1 question per category"
        case .medium: return "2 questions per category"
        case .large:  return "3 questions per category"
        }
    }
}

// MARK: - InterviewQuestion

struct InterviewQuestion: Identifiable {
    let id: String
    let category: InterviewCategory
    let de: String
    let en: String
    let answerDE: String?
    let answerEN: String?
}

// MARK: - Question Pool

extension InterviewQuestion {

    static func randomSession(size: SessionSize) -> [InterviewQuestion] {
        InterviewCategory.allCases.flatMap { cat in
            all.filter { $0.category == cat }.shuffled().prefix(size.questionsPerCategory)
        }
    }

    static let all: [InterviewQuestion] = math + physics + navigation + aviation + english + spatial + personality + judgment

    // ── Kopfrechnen ──────────────────────────────────────────────────────────
    static let math: [InterviewQuestion] = [
        .init(id: "m01", category: .math,
              de: "37 × 8 = ?", en: "37 × 8 = ?",
              answerDE: "296", answerEN: "296"),
        .init(id: "m02", category: .math,
              de: "144 ÷ 12 = ?", en: "144 ÷ 12 = ?",
              answerDE: "12", answerEN: "12"),
        .init(id: "m03", category: .math,
              de: "15 % von 240 = ?", en: "15 % of 240 = ?",
              answerDE: "36", answerEN: "36"),
        .init(id: "m04", category: .math,
              de: "125 × 4 = ?", en: "125 × 4 = ?",
              answerDE: "500", answerEN: "500"),
        .init(id: "m05", category: .math,
              de: "270 ÷ 9 = ?", en: "270 ÷ 9 = ?",
              answerDE: "30", answerEN: "30"),
        .init(id: "m06", category: .math,
              de: "23 + 47 + 86 = ?", en: "23 + 47 + 86 = ?",
              answerDE: "156", answerEN: "156"),
        .init(id: "m07", category: .math,
              de: "Quadratwurzel aus 196 = ?", en: "Square root of 196 = ?",
              answerDE: "14", answerEN: "14"),
        .init(id: "m08", category: .math,
              de: "3/4 von 480 = ?", en: "3/4 of 480 = ?",
              answerDE: "360", answerEN: "360"),
        .init(id: "m09", category: .math,
              de: "17 × 17 = ?", en: "17 × 17 = ?",
              answerDE: "289", answerEN: "289"),
        .init(id: "m10", category: .math,
              de: "450 km in 1,5 h → Durchschnittsgeschwindigkeit = ?", en: "450 km in 1.5 h → average speed = ?",
              answerDE: "300 km/h", answerEN: "300 km/h"),
        .init(id: "m11", category: .math,
              de: "360 ÷ 8 × 3 = ?", en: "360 ÷ 8 × 3 = ?",
              answerDE: "135", answerEN: "135"),
        .init(id: "m12", category: .math,
              de: "25 % von 360 = ?", en: "25 % of 360 = ?",
              answerDE: "90", answerEN: "90"),
        .init(id: "m13", category: .math,
              de: "Flugzeit: 780 km bei 260 km/h = ? Stunden", en: "Flight time: 780 km at 260 km/h = ? hours",
              answerDE: "3 Stunden", answerEN: "3 hours"),
    ]

    // ── Physik & Technik ─────────────────────────────────────────────────────
    static let physics: [InterviewQuestion] = [
        .init(id: "p01", category: .physics,
              de: "Was ist Auftrieb und wovon hängt er ab?", en: "What is lift and what does it depend on?",
              answerDE: nil, answerEN: nil),
        .init(id: "p02", category: .physics,
              de: "Erkläre das Bernoulli-Prinzip im Kontext des Fliegens.", en: "Explain the Bernoulli principle in the context of flight.",
              answerDE: nil, answerEN: nil),
        .init(id: "p03", category: .physics,
              de: "Was ist der Unterschied zwischen statischem und dynamischem Druck?", en: "What is the difference between static and dynamic pressure?",
              answerDE: nil, answerEN: nil),
        .init(id: "p04", category: .physics,
              de: "Warum nimmt die Luftdichte mit der Höhe ab?", en: "Why does air density decrease with altitude?",
              answerDE: nil, answerEN: nil),
        .init(id: "p05", category: .physics,
              de: "Was versteht man unter dem Überziehwinkel (Critical Angle of Attack)?", en: "What is the critical angle of attack (stall angle)?",
              answerDE: nil, answerEN: nil),
        .init(id: "p06", category: .physics,
              de: "Wie funktioniert ein Strahltriebwerk – Grundprinzip?", en: "How does a jet engine work – basic principle?",
              answerDE: nil, answerEN: nil),
        .init(id: "p07", category: .physics,
              de: "Was ist Schub und wie wird er erzeugt?", en: "What is thrust and how is it generated?",
              answerDE: nil, answerEN: nil),
        .init(id: "p08", category: .physics,
              de: "Was sind die vier Kräfte, die auf ein Flugzeug im Reiseflug wirken?", en: "What are the four forces acting on an aircraft in cruise?",
              answerDE: nil, answerEN: nil),
        .init(id: "p09", category: .physics,
              de: "Was bewirkt Vereisung an Tragflächen?", en: "What effect does icing have on wings?",
              answerDE: nil, answerEN: nil),
        .init(id: "p10", category: .physics,
              de: "Was ist Drehmoment (Torque) und wie beeinflusst es ein Propellerflugzeug?", en: "What is torque and how does it affect a propeller aircraft?",
              answerDE: nil, answerEN: nil),
        .init(id: "p11", category: .physics,
              de: "Warum ist Hypoxie in großer Höhe gefährlich?", en: "Why is hypoxia dangerous at high altitude?",
              answerDE: nil, answerEN: nil),
        .init(id: "p12", category: .physics,
              de: "Erkläre den Unterschied zwischen Propeller und Turbofan-Triebwerk.", en: "Explain the difference between a propeller and a turbofan engine.",
              answerDE: nil, answerEN: nil),
    ]

    // ── Navigation & Wetter ─────────────────────────────────────────────────
    static let navigation: [InterviewQuestion] = [
        .init(id: "n01", category: .navigation,
              de: "Was bedeutet QNH?", en: "What does QNH mean?",
              answerDE: nil, answerEN: nil),
        .init(id: "n02", category: .navigation,
              de: "Was ist der Unterschied zwischen wahrer und magnetischer Missweisung?", en: "What is the difference between true and magnetic variation?",
              answerDE: nil, answerEN: nil),
        .init(id: "n03", category: .navigation,
              de: "Was versteht man unter einem Hochdruckgebiet und wie dreht der Wind in der Nordhalbkugel?", en: "What is a high-pressure system and which way does wind rotate in the northern hemisphere?",
              answerDE: nil, answerEN: nil),
        .init(id: "n04", category: .navigation,
              de: "Was ist METAR und welche Informationen enthält es?", en: "What is a METAR and what information does it contain?",
              answerDE: nil, answerEN: nil),
        .init(id: "n05", category: .navigation,
              de: "Erkläre den Unterschied zwischen TAF und METAR.", en: "Explain the difference between a TAF and METAR.",
              answerDE: nil, answerEN: nil),
        .init(id: "n06", category: .navigation,
              de: "Was ist eine Inversion in der Atmosphäre?", en: "What is a temperature inversion in the atmosphere?",
              answerDE: nil, answerEN: nil),
        .init(id: "n07", category: .navigation,
              de: "Was bedeutet VFR und IFR?", en: "What do VFR and IFR mean?",
              answerDE: nil, answerEN: nil),
        .init(id: "n08", category: .navigation,
              de: "Was ist Cumulonimbus und warum ist er gefährlich?", en: "What is a cumulonimbus cloud and why is it dangerous?",
              answerDE: nil, answerEN: nil),
        .init(id: "n09", category: .navigation,
              de: "Wie funktioniert GPS-Navigation im Luftfahrtbereich?", en: "How does GPS navigation work in aviation?",
              answerDE: nil, answerEN: nil),
        .init(id: "n10", category: .navigation,
              de: "Was sind Windscherung und Turbulenz?", en: "What are wind shear and turbulence?",
              answerDE: nil, answerEN: nil),
        .init(id: "n11", category: .navigation,
              de: "Was ist der Unterschied zwischen Streckenflug (IFR) und Sichtflug (VFR)?", en: "What is the difference between IFR and VFR flight?",
              answerDE: nil, answerEN: nil),
        .init(id: "n12", category: .navigation,
              de: "Was bedeutet QFE im Gegensatz zu QNH?", en: "What does QFE mean compared to QNH?",
              answerDE: nil, answerEN: nil),
    ]

    // ── Luftfahrtkunde ───────────────────────────────────────────────────────
    static let aviation: [InterviewQuestion] = [
        .init(id: "a01", category: .aviation,
              de: "Welche Lufträume gibt es in Deutschland?", en: "What airspace classes exist in Germany?",
              answerDE: nil, answerEN: nil),
        .init(id: "a02", category: .aviation,
              de: "Was ist der Unterschied zwischen Flughafen, Flugplatz und Segelfluggelände?", en: "What is the difference between an airport, an airfield, and a glider site?",
              answerDE: nil, answerEN: nil),
        .init(id: "a03", category: .aviation,
              de: "Was ist ein NOTAM?", en: "What is a NOTAM?",
              answerDE: nil, answerEN: nil),
        .init(id: "a04", category: .aviation,
              de: "Was ist der Unterschied zwischen PPL und ATPL?", en: "What is the difference between a PPL and an ATPL?",
              answerDE: nil, answerEN: nil),
        .init(id: "a05", category: .aviation,
              de: "Was regelt die EASA und was die ICAO?", en: "What does EASA regulate and what does ICAO regulate?",
              answerDE: nil, answerEN: nil),
        .init(id: "a06", category: .aviation,
              de: "Was ist ein Transponder und welchen Modus verwenden Airliner?", en: "What is a transponder and which mode do airliners use?",
              answerDE: nil, answerEN: nil),
        .init(id: "a07", category: .aviation,
              de: "Was versteht man unter einem ILS-Anflug?", en: "What is an ILS approach?",
              answerDE: nil, answerEN: nil),
        .init(id: "a08", category: .aviation,
              de: "Was ist ein schwarzes Brett-Flug (Black Box) und was wird aufgezeichnet?", en: "What is a flight data recorder (black box) and what does it record?",
              answerDE: nil, answerEN: nil),
        .init(id: "a09", category: .aviation,
              de: "Welche Mindestausrüstung benötigt ein IFR-Flugzeug?", en: "What minimum equipment is required for IFR flight?",
              answerDE: nil, answerEN: nil),
        .init(id: "a10", category: .aviation,
              de: "Was ist Wake Turbulence und von welchen Flugzeugkategorien geht sie aus?", en: "What is wake turbulence and which aircraft categories produce it?",
              answerDE: nil, answerEN: nil),
        .init(id: "a11", category: .aviation,
              de: "Was ist eine TCAS-Warnung?", en: "What is a TCAS alert?",
              answerDE: nil, answerEN: nil),
        .init(id: "a12", category: .aviation,
              de: "Erkläre den Unterschied zwischen Autopilot und Autothrottle.", en: "Explain the difference between autopilot and autothrottle.",
              answerDE: nil, answerEN: nil),
    ]

    // ── Aviation English ─────────────────────────────────────────────────────
    static let english: [InterviewQuestion] = [
        .init(id: "e01", category: .english,
              de: "Was ist das phonetische Alphabet für 'P'?", en: "What is the phonetic alphabet for 'P'?",
              answerDE: "Papa", answerEN: "Papa"),
        .init(id: "e02", category: .english,
              de: "Was ist das phonetische Alphabet für 'M'?", en: "What is the phonetic alphabet for 'M'?",
              answerDE: "Mike", answerEN: "Mike"),
        .init(id: "e03", category: .english,
              de: "Was ist das phonetische Alphabet für 'W'?", en: "What is the phonetic alphabet for 'W'?",
              answerDE: "Whiskey", answerEN: "Whiskey"),
        .init(id: "e04", category: .english,
              de: "Was bedeutet 'Mayday' und wann wird es verwendet?", en: "What does 'Mayday' mean and when is it used?",
              answerDE: "Höchste Notlage, unmittelbare Lebensgefahr (franz. m'aidez)", answerEN: "Highest emergency, immediate danger to life (from French m'aidez)"),
        .init(id: "e05", category: .english,
              de: "Was bedeutet 'Pan Pan' im Sprechfunk?", en: "What does 'Pan Pan' mean on the radio?",
              answerDE: "Dringlichkeitsruf – ernste Situation, keine unmittelbare Lebensgefahr", answerEN: "Urgency call – serious situation, no immediate danger to life"),
        .init(id: "e06", category: .english,
              de: "Übersetze: 'Cleared for takeoff, runway 27 left.'", en: "Translate: 'Cleared for takeoff, runway 27 left.'",
              answerDE: "Startfreigabe, Runway 27 links", answerEN: "Cleared for takeoff, runway 27 left."),
        .init(id: "e07", category: .english,
              de: "Was ist das phonetische Alphabet für 'F' und 'J'?", en: "What is the phonetic alphabet for 'F' and 'J'?",
              answerDE: "Foxtrot, Juliet", answerEN: "Foxtrot, Juliet"),
        .init(id: "e08", category: .english,
              de: "Was bedeutet 'Roger' im Sprechfunk?", en: "What does 'Roger' mean on the radio?",
              answerDE: "Nachricht empfangen und verstanden", answerEN: "Message received and understood"),
        .init(id: "e09", category: .english,
              de: "Was bedeutet 'Wilco'?", en: "What does 'Wilco' mean?",
              answerDE: "Will comply – Anweisung verstanden und wird ausgeführt", answerEN: "Will comply – instruction understood and will be carried out"),
        .init(id: "e10", category: .english,
              de: "Was bedeutet 'Squawk 7700'?", en: "What does 'Squawk 7700' mean?",
              answerDE: "Notfall-Transpondercode", answerEN: "Emergency transponder code"),
        .init(id: "e11", category: .english,
              de: "Wie lautet die Standard-Redewendung für eine Landeanfrage?", en: "What is the standard phraseology for requesting landing clearance?",
              answerDE: "\"[Rufzeichen] request landing clearance runway [XX]\"", answerEN: "\"[Callsign] request landing clearance runway [XX]\""),
        .init(id: "e12", category: .english,
              de: "Was bedeutet 'Hold short of runway' ?", en: "What does 'Hold short of runway' mean?",
              answerDE: "Vor der Runway-Schwelle stehenbleiben, nicht einfahren", answerEN: "Stop before the runway threshold, do not enter"),
    ]

    // ── Räumliches Denken ────────────────────────────────────────────────────
    static let spatial: [InterviewQuestion] = [
        .init(id: "s01", category: .spatial,
              de: "Welche Form entsteht, wenn du einen Würfel diagonal schneidest?", en: "What shape do you get when you cut a cube diagonally?",
              answerDE: "Rechteck", answerEN: "Rectangle"),
        .init(id: "s02", category: .spatial,
              de: "Ein Flugzeug dreht 90° nach rechts, dann 180° nach links – in welche Richtung fliegt es jetzt?", en: "An aircraft turns 90° right, then 180° left – which direction is it now facing?",
              answerDE: "90° links von der ursprünglichen Richtung", answerEN: "90° left of the original heading"),
        .init(id: "s03", category: .spatial,
              de: "Du fliegst nach Norden. Du drehst 135° nach rechts. Wohin fliegst du jetzt?", en: "You fly north. You turn 135° right. What direction are you now flying?",
              answerDE: "Südost (135°)", answerEN: "Southeast (135°)"),
        .init(id: "s04", category: .spatial,
              de: "Wie viele Würfel hat ein 3×3×3-Kubus insgesamt? Wie viele sind innen?", en: "How many cubes make up a 3×3×3 cube? How many are inside?",
              answerDE: "27 gesamt, 1 innen", answerEN: "27 total, 1 inside"),
        .init(id: "s05", category: .spatial,
              de: "Ein Kreis wird von rechts abgeflacht – welche Form entsteht?", en: "A circle is flattened from the right – what shape is created?",
              answerDE: "Ellipse (Oval)", answerEN: "Ellipse (Oval)"),
        .init(id: "s06", category: .spatial,
              de: "Du siehst ein Flugzeug von oben. Es fliegt nach Norden und dreht links. Was siehst du?", en: "You see an aircraft from above flying north and turning left. What do you see?",
              answerDE: "Das Flugzeug dreht nach Westen", answerEN: "The aircraft turns westward"),
        .init(id: "s07", category: .spatial,
              de: "Ein Zylinder wird senkrecht zur Längsachse geschnitten – welche Form entsteht?", en: "A cylinder is cut perpendicular to its long axis – what shape results?",
              answerDE: "Kreis", answerEN: "Circle"),
        .init(id: "s08", category: .spatial,
              de: "Du fliegst nach Osten auf 2000 ft. Du steigst auf 3000 ft. Dein Schatten bewegt sich nach …?", en: "You fly east at 2000 ft and climb to 3000 ft. Your shadow moves …?",
              answerDE: "Nach wie vor nach Osten (Richtung unverändert)", answerEN: "Still eastward (direction unchanged)"),
        .init(id: "s09", category: .spatial,
              de: "Wie viele Flächen hat ein regulärer Oktaeder?", en: "How many faces does a regular octahedron have?",
              answerDE: "8 Flächen", answerEN: "8 faces"),
        .init(id: "s10", category: .spatial,
              de: "Du fliegst auf einem Kurs von 270° und drehst 90° nach links. Auf welchem Kurs bist du?", en: "You fly on a heading of 270° and turn 90° left. What is your new heading?",
              answerDE: "180°", answerEN: "180°"),
        .init(id: "s11", category: .spatial,
              de: "Ein Dreieck wird gespiegelt und dann 180° gedreht. Wie sieht es aus?", en: "A triangle is mirrored and then rotated 180°. How does it look?",
              answerDE: "Identisch mit dem Original (Spiegelung + 180°-Drehung = dasselbe)", answerEN: "Identical to the original (mirror + 180° rotation = same result)"),
        .init(id: "s12", category: .spatial,
              de: "Stelle dir ein Flugzeug vor, das aus 1000 ft in einer steilen Linkskurve sinkt. Wo ist die linke Tragfläche?", en: "Imagine an aircraft descending from 1000 ft in a steep left bank. Where is the left wing?",
              answerDE: "Unten (zeigt Richtung Boden)", answerEN: "Down (pointing toward the ground)"),
    ]

    // ── Motivation & Persönlichkeit ──────────────────────────────────────────
    static let personality: [InterviewQuestion] = [
        .init(id: "per01", category: .personality,
              de: "Warum möchtest du Pilot werden?", en: "Why do you want to become a pilot?",
              answerDE: nil, answerEN: nil),
        .init(id: "per02", category: .personality,
              de: "Wie gehst du mit Stress und Druck um?", en: "How do you handle stress and pressure?",
              answerDE: nil, answerEN: nil),
        .init(id: "per03", category: .personality,
              de: "Beschreibe eine Situation, in der du eine schwierige Entscheidung treffen musstest.", en: "Describe a situation where you had to make a difficult decision.",
              answerDE: nil, answerEN: nil),
        .init(id: "per04", category: .personality,
              de: "Wie reagierst du, wenn du einen Fehler gemacht hast?", en: "How do you react when you have made a mistake?",
              answerDE: nil, answerEN: nil),
        .init(id: "per05", category: .personality,
              de: "Was sind deine größten Stärken und Schwächen?", en: "What are your greatest strengths and weaknesses?",
              answerDE: nil, answerEN: nil),
        .init(id: "per06", category: .personality,
              de: "Wie arbeitest du in einem Team?", en: "How do you work in a team?",
              answerDE: nil, answerEN: nil),
        .init(id: "per07", category: .personality,
              de: "Was würdest du tun, wenn du nach 5 Jahren merkst, dass du doch kein Pilot werden möchtest?", en: "What would you do if after 5 years you realized you no longer want to be a pilot?",
              answerDE: nil, answerEN: nil),
        .init(id: "per08", category: .personality,
              de: "Was motiviert dich außer dem Fliegen selbst?", en: "What motivates you besides flying itself?",
              answerDE: nil, answerEN: nil),
        .init(id: "per09", category: .personality,
              de: "Wie gehst du mit Kritik von Vorgesetzten um?", en: "How do you handle criticism from superiors?",
              answerDE: nil, answerEN: nil),
        .init(id: "per10", category: .personality,
              de: "Hast du bereits Flugerfahrung? Wenn ja, beschreibe dein bisher beeindruckendstes Erlebnis.", en: "Do you have any flight experience? If so, describe your most impressive experience so far.",
              answerDE: nil, answerEN: nil),
        .init(id: "per11", category: .personality,
              de: "Wie stellst du sicher, dass du im Cockpit fokussiert und ausgeruht bist?", en: "How do you ensure you are focused and rested in the cockpit?",
              answerDE: nil, answerEN: nil),
        .init(id: "per12", category: .personality,
              de: "Wo siehst du dich in 10 Jahren als Pilot?", en: "Where do you see yourself as a pilot in 10 years?",
              answerDE: nil, answerEN: nil),
    ]

    // ── Situatives Urteil ────────────────────────────────────────────────────
    static let judgment: [InterviewQuestion] = [
        .init(id: "j01", category: .judgment,
              de: "Du siehst ein Warnlicht im Cockpit und bist im Final. Was tust du?", en: "You see a warning light in the cockpit and are on final approach. What do you do?",
              answerDE: nil, answerEN: nil),
        .init(id: "j02", category: .judgment,
              de: "Dein Co-Pilot macht einen Fehler, den du bemerkst. Wie reagierst du?", en: "Your co-pilot makes an error that you notice. How do you react?",
              answerDE: nil, answerEN: nil),
        .init(id: "j03", category: .judgment,
              de: "Du fliegst bei schlechtem Wetter und der Treibstoff reicht knapp. Was entscheidest du?", en: "You're flying in bad weather and fuel is running low. What is your decision?",
              answerDE: nil, answerEN: nil),
        .init(id: "j04", category: .judgment,
              de: "Ein Passagier wird medizinisch auffällig während des Fluges. Was ist dein Vorgehen?", en: "A passenger shows medical symptoms during a flight. What is your procedure?",
              answerDE: nil, answerEN: nil),
        .init(id: "j05", category: .judgment,
              de: "Du erhältst widersprüchliche Anweisungen vom Tower. Wie gehst du vor?", en: "You receive contradictory instructions from the tower. How do you proceed?",
              answerDE: nil, answerEN: nil),
        .init(id: "j06", category: .judgment,
              de: "Kurz vor dem Abheben bemerkst du eine ungewöhnliche Vibration. Was machst du?", en: "Just before takeoff you notice an unusual vibration. What do you do?",
              answerDE: nil, answerEN: nil),
        .init(id: "j07", category: .judgment,
              de: "Dein Captain entscheidet sich für eine Landung bei Bedingungen, die du für grenzwertig hältst. Wie gehst du vor?", en: "Your captain decides to land in conditions you consider borderline. What do you do?",
              answerDE: nil, answerEN: nil),
        .init(id: "j08", category: .judgment,
              de: "Du bist übermüdet vor einem frühen Flug. Was tust du?", en: "You are fatigued before an early-morning flight. What do you do?",
              answerDE: nil, answerEN: nil),
        .init(id: "j09", category: .judgment,
              de: "Ein anderer Pilot berichtet, er habe Alkohol getrunken. Was unternimmst du?", en: "Another pilot reports having had alcohol. What do you do?",
              answerDE: nil, answerEN: nil),
        .init(id: "j10", category: .judgment,
              de: "Du bemerkst beim Briefing, dass eine wichtige Information im Flugplan fehlt. Was tust du?", en: "During briefing you notice that important information is missing from the flight plan. What do you do?",
              answerDE: nil, answerEN: nil),
        .init(id: "j11", category: .judgment,
              de: "Du fliegst nachts und verlierst für kurze Zeit die Orientierung. Was sind deine ersten Schritte?", en: "You are flying at night and briefly lose your orientation. What are your first steps?",
              answerDE: nil, answerEN: nil),
        .init(id: "j12", category: .judgment,
              de: "Die Kabine verliert unerwartet an Druck. Welche Sofortmaßnahmen leitest du ein?", en: "The cabin unexpectedly loses pressure. What immediate actions do you take?",
              answerDE: nil, answerEN: nil),
    ]
}
