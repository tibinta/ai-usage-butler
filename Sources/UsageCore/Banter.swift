import Foundation

public enum Banter {
    public static let greenLines = [
        "Go on, boss, those tokens can take it!",
        "Look at you, using the good stuff properly.",
        "That’s the pace, you clever prompt machine.",
        "Green lights and good vibes. Carry on, mate.",
        "You’ve got headroom. Go make something brilliant.",
        "The quota’s chilling. You can crack on, boss.",
        "Prompts behaving, allowance happy. Lovely stuff.",
        "You’re cruising. Keep that cleverness coming.",
        "That’s a tidy pace. Go on, show-off.",
        "Look at you, leaving room for one more good idea.",
        "Quota says carry on. I say nice work, boss.",
        "Plenty of runway. Get those ideas airborne.",
        "Steady engine, clear skies. Off you pop.",
        "You’re using it like a seasoned pro. Keep at it.",
        "That usage is chef’s kiss. Keep cooking, mate.",
        "Good pace, good choices. Go on, legend.",
        "All green. Your next bright idea is welcome."
    ]

    public static let amberLines = [
        "Easy there, boss. Keep an eye on that headroom.",
        "Steady on, mate. You’ve got this.",
        "A little less sprint, a little more stroll, yeah?",
        "You’re alright. Just mind the meter, love.",
        "Keep it measured, you magnificent prompt gremlin.",
        "Nearly at the bend. Take it steady, boss.",
        "A sensible pace looks good on you, mate.",
        "Easy does it. The quota’s still in the game.",
        "Keep your wits and a bit of headroom, darling.",
        "The meter’s giving you the side-eye. Pace it.",
        "You’re doing fine. Maybe skip the prompt marathon.",
        "Steady hands, clever plans. You know the drill.",
        "Easy there, boss. Take a breath.",
        "The quota can wait a moment, mate.",
        "Easy does it, love. No need to push.",
        "A breather sounds like a grand idea."
    ]

    public static let redLines = [
        "How the fuck did you burn through it so fast? Building GTA 6?!",
        "You’re fucked at this pace, mate. Ease off a touch.",
        "Your prompts have a faster lane than the M25.",
        "Well, shit. That usage graph needs a seatbelt.",
        "You’re rinsing tokens like it’s happy hour, champ.",
        "Blimey, even free office biscuits last longer than that.",
        "It said ‘slow down’; you heard ‘hold my beer.’",
        "That prompt pace is absolutely bloody flying, love.",
        "You’re driving the quota like you stole it, mate.",
        "Bollocks, that’s a brisk little burn rate.",
        "Your tokens are doing a sprint. Maybe try a stroll?",
        "‘Just one more prompt’ is a dangerous little phrase.",
        "The meter’s sweating. You might be typing too fast.",
        "You’re giving that allowance a proper workout today.",
        "The usage goblin’s jogging to keep up with you.",
        "Well, that escalated faster than a group chat.",
        "That pace has less chill than a laptop fan, mate."
    ]

    public static var lines: [String] { greenLines + amberLines + redLines }

    public static func line(color: String, pause: Bool = false, now: Date) -> String {
        let group = color == "green" ? greenLines : color == "red" ? redLines : pause ? Array(amberLines.suffix(4)) : amberLines
        let hour = Int(now.timeIntervalSince1970 / 3600)
        return group[hour % group.count]
    }

    public static func menuPhrase(color: String, pause: Bool = false) -> String {
        switch color {
        case "green": "go on, boss!"
        case "red": "you’re fucked, mate!"
        default: pause ? "easy there, boss!" : "steady on, boss!"
        }
    }
}
