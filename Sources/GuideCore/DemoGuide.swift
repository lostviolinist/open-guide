import Foundation

public enum DemoGuide {
    public static let introduction = """
    {"version":1,"title":"A little guidance, right where you need it","steps":[
      {"id":"notice","narration":"OpenGuide connects an explanation to the thing you are looking at. This highlight is drawn natively on your Mac.","marks":[
        {"id":"outline","kind":"highlight","color":"mint","rect":{"x":0.08,"y":0.18,"width":0.84,"height":0.34}},
        {"id":"caption","kind":"label","color":"mint","rect":{"x":0.1,"y":0.08,"width":0.8,"height":0.08},"text":"1 · Understand the context"}]},
      {"id":"connect","narration":"Drawings change with each spoken step. Hover inside the amber box to continue this local demonstration.","marks":[
        {"id":"arrow","kind":"arrow","color":"blue","from":{"x":0.5,"y":0.36},"to":{"x":0.5,"y":0.67}},
        {"id":"target","kind":"highlight","color":"amber","rect":{"x":0.3,"y":0.68,"width":0.4,"height":0.16}}],
        "interaction":{"kind":"hover","target":{"x":0.3,"y":0.68,"width":0.4,"height":0.16},"label":"Hover here to reveal the next step","dwellMilliseconds":700}}
    ]}
    """
    public static let continuation = """
    {"version":1,"title":"The loop is complete","steps":[
      {"id":"complete","narration":"You did it. In a live session, OpenGuide now captures the selected region again and asks the model what changed. This demo stays entirely on your Mac.","marks":[
        {"id":"done","kind":"label","color":"mint","rect":{"x":0.12,"y":0.28,"width":0.76,"height":0.2},"text":"Observe → explain → interact → observe"}]}]}
    """
}
