load("render.star", "render")
load("schema.star", "schema")

DEFAULT_LOCATION = "Hauptplatz"

def main(config):
    location = config.get("location") or DEFAULT_LOCATION
    return render.Root(
    child = render.Text("Hello, %s" %location)
    )

def get_schema():
    options = [
        schema.Option(
            display = "Kudlichstraße",
            value = "Linz/Donau Kudlichstraße",
        ),
        schema.Option(
            display = "Landwiedstraße",
            value = "Linz/Donau Landwiedstraße",
        ),
    ]

    return schema.Schema(
        version = "0.1",
        fields = [
            schema.Dropdown(
                id = "location",
                name = "Bus Stop",
                desc = "Location where you want to depart",
                icon = "gear",
                default = options[0].value,
                options = options,
            ),
        ],
    )