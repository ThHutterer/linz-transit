load("render.star", "render")
load("schema.star", "schema")
load("http.star", "http")
load("encoding/json.star", "json")

DEFAULT_LOCATION = """{
    "lat": "48.18471716633556",
    "long": "16.377438897711873",
	"description": "Wien, Austria",
	"locality": "Wien HBF",
	"place_id": "xxxx",
	"timezone": "Europe/Zurich"
}"""

BASE_REST_CALL = """https://routenplaner.verkehrsauskunft.at/vao/restproxy/
v1.6.0/{endpoint}?accessId={api_key}&format=json/"""

def main(config):
    stop_info = get_stop_infos(config)
    print(stop_info)
    return render.Root(
    child = render.Text("Hello")
    )

def get_stop_infos(config):
    location = config.get("location", DEFAULT_LOCATION)
    loc = json.decode(location)
    rest_call_stop_info = BASE_REST_CALL.format(
        endpoint = "location.nearbystops",
        api_key = config.get("key")
    )
    return rest_call_stop_info


def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "key",
                name = "API key",
                desc = "Paste your VAO API Key here",
                icon = "gear",
                default = "703c9bf-e119-44b4-84c5-dac1a92b827e"
            ),
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Location for which you want to know the next stop.",
                icon = "locationDot",
            ),

        ],
    )