/// First-aid protocol content and the scripted assistant replies from the prototype.
/// NOTE: These protocols are placeholders from the design. Blueprint requires clinician
/// review, versioning and source linking before release.
class Guide {
  final String id, title, sub, cat, icon, mins, warn;
  final List<String> steps;
  final String tone; // red | amb | acc | ice
  const Guide(this.id, this.title, this.sub, this.cat, this.icon, this.tone, this.mins, this.steps, this.warn);
}

const guides = <Guide>[
  Guide('bleeding', 'Severe bleeding', 'Control it in 10 minutes', 'First aid', 'drop', 'red', '4 min', [
    'Call for help or start the SOS beacon before anything else.',
    'Press firmly on the wound with a clean cloth or clothing.',
    'Keep pressure for 10 minutes without lifting to check.',
    'If blood soaks through, add more cloth on top. Do not remove the first layer.',
    'Raise the limb above heart level and keep the person warm.',
  ], 'blood spurts, soaks through several layers, or the person turns pale or confused.'),
  Guide('burns', 'Burns & scalds', 'Cool, cover, protect', 'First aid', 'flame', 'amb', '3 min', [
    'Move away from the heat source.',
    'Cool with clean running water for 20 minutes.',
    'Remove rings and watches near the burn before swelling.',
    'Cover loosely with a clean non-fluffy dressing or cling film.',
    'Do not pop blisters or apply butter, oil or ice.',
  ], 'the burn is larger than your palm, on the face, hands or joints, or looks white or charred.'),
  Guide('fracture', 'Fractures & sprains', 'Immobilise and evacuate', 'First aid', 'bone', 'acc', '6 min', [
    'Keep the person still and support the injured part.',
    'Pad and splint above and below the injury with sticks or a pack frame.',
    'Check feeling, colour and pulse beyond the splint.',
    'Apply cold for 15 minutes if you have it.',
    'Plan a slow, assisted descent or wait for rescue.',
  ], 'bone is visible, the limb looks deformed, or fingers and toes turn cold or numb.'),
  Guide('choking', 'Choking & breathing', 'Recognise and act fast', 'Breathing', 'lungs', 'ice', '3 min', [
    'Ask "Are you choking?" If they cannot speak or cough, act now.',
    'Give up to 5 firm back blows between the shoulder blades.',
    'Give up to 5 abdominal thrusts if the blockage remains.',
    'Alternate back blows and thrusts until it clears.',
    'If they become unresponsive, start CPR and call for help.',
  ], 'they cannot breathe, turn blue, or lose consciousness.'),
  Guide('unconscious', 'Unconscious person', 'Check, position, monitor', 'Breathing', 'person', 'ice', '4 min', [
    'Check the scene is safe, then tap and shout to get a response.',
    'Open the airway by tilting the head back and lifting the chin.',
    'Look, listen and feel for normal breathing for 10 seconds.',
    'If breathing, roll onto their side in the recovery position.',
    'If not breathing, call for help and start CPR.',
  ], 'they are not responding, not breathing normally, or you are unsure.'),
  Guide('hypothermia', 'Hypothermia', 'Warm the core first', 'Environment', 'snow', 'ice', '5 min', [
    'Get out of wind and rain. Insulate from the ground.',
    'Replace wet clothing with dry layers and a hat.',
    'Wrap the torso first. Add a vapour barrier if available.',
    'Give warm sweet drinks only if fully awake.',
    'Do not rub limbs or use direct heat on the skin.',
  ], 'shivering stops, speech slurs, or the person becomes drowsy.'),
  Guide('heat', 'Dehydration & heat', 'Rest, cool, sip', 'Environment', 'sun', 'amb', '3 min', [
    'Move to shade and stop exercising.',
    'Sip water or electrolyte mix in small amounts.',
    'Cool the neck, armpits and groin with wet cloth.',
    'Loosen clothing and fan the person.',
    'Rest until urine is pale and headache clears.',
  ], 'the person is confused, stops sweating, or vomits repeatedly.'),
  Guide('altitude', 'Altitude sickness', 'Headache, nausea, fatigue', 'Environment', 'mtn', 'acc', '4 min', [
    'Stop ascending and rest.',
    'Drink water and eat light carbohydrates.',
    'Take pain relief for headache if you have it.',
    'Descend 300 to 500 m if symptoms do not ease in a few hours.',
    'Never ascend while symptoms are worsening.',
  ], 'confusion, loss of balance, breathlessness at rest, or a wet cough.'),
  Guide('bites', 'Bites & stings', 'Snakes, insects, ticks', 'Bites', 'warn', 'red', '4 min', [
    'Move away from the animal and keep calm.',
    'Keep the bitten limb still and at heart level.',
    'Remove rings and tight items near the bite.',
    'Mark the swelling edge with a pen and note the time.',
    'Do not cut, suck or apply a tourniquet.',
  ], 'any snake bite, trouble breathing, or swelling of the face or throat.'),
  Guide('kit', 'First-aid kit', 'Pack list for a trek', 'Preparedness', 'cross', 'acc', '2 min', [
    'Pressure dressings and sterile gauze.',
    'Elastic bandage, triangular bandage and tape.',
    'Antiseptic wipes, gloves and a CPR face shield.',
    'Whistle, foil blanket and a headlamp.',
    'Personal medicines and your Medical ID card.',
  ], 'you are unsure an item is safe for you. Ask a clinician before your trip.'),
];

Guide guideById(String id) => guides.firstWhere((g) => g.id == id, orElse: () => guides.first);

const libraryCats = ['All', 'First aid', 'Breathing', 'Environment', 'Bites', 'Preparedness'];

class Reply {
  final List<String> keys;
  final String? guide;
  final String text;
  final List<String> steps;
  const Reply(this.keys, this.guide, this.text, this.steps);
}

const replies = <Reply>[
  Reply(['bleed', 'cut', 'blood', 'wound'], 'bleeding', 'That sounds like a bleeding injury. Here is what to do now.',
      ['Press firmly with a clean cloth.', 'Hold for 10 minutes without lifting.', 'Raise the limb above your heart.']),
  Reply(['cold', 'shiver', 'freez', 'hypo'], 'hypothermia', 'Warmth first. Get out of the wind and rain.',
      ['Swap wet clothes for dry layers.', 'Insulate from the ground.', 'Wrap the torso and sip something warm.']),
  Reply(['snake', 'bite', 'sting', 'tick'], 'bites', 'Stay calm and still. Movement spreads venom faster.',
      ['Move away from the animal.', 'Keep the limb still, level with your heart.', 'Mark the swelling edge and note the time.']),
  Reply(['ankle', 'broke', 'fractur', 'sprain', 'leg'], 'fracture', 'Treat it as a fracture until proven otherwise.',
      ['Keep the leg still and supported.', 'Splint above and below the injury.', 'Check toes for colour and feeling.']),
  Reply(['water', 'thirst', 'dehydr', 'heat'], 'heat', 'Slow down and cool off before anything else.',
      ['Move to shade and rest.', 'Sip fluids in small amounts.', 'Cool your neck and armpits.']),
  Reply(['burn', 'scald', 'fire'], 'burns', 'Cool the burn straight away.',
      ['Run clean water over it for 20 minutes.', 'Remove rings and watches nearby.', 'Cover loosely. Do not pop blisters.']),
];

const photoReply = Reply([], 'bleeding',
    'Gemma analysed your photo on this device. It looks like an open wound with light bleeding. Here is what to do.',
    ['Rinse with clean water if available.', 'Press with a clean cloth for 10 minutes.', 'Cover with a dressing and watch for redness.']);

const fallbackReply = Reply([], null,
    'I can help with that. Tell me who is hurt, what happened, and whether they are awake and breathing.',
    ['Check the scene is safe.', 'Check they respond and breathe normally.', 'Tell me the main symptom.']);

/// Assistant seam. The prototype uses keyword matching; swap this for an on-device
/// Gemma (LiteRT) implementation that still routes emergencies through [guides].
abstract class AssistantEngine {
  Future<Reply> respond(String text, {bool hasImage = false});
}

class ScriptedAssistant implements AssistantEngine {
  @override
  Future<Reply> respond(String text, {bool hasImage = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final l = text.toLowerCase();
    for (final r in replies) {
      if (r.keys.any(l.contains)) return r;
    }
    return hasImage ? photoReply : fallbackReply;
  }
}
