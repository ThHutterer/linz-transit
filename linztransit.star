load("render.star", "render")
load("schema.star", "schema")
load("http.star", "http")
load("encoding/json.star", "json")

DEFAULT_LOCATION = """{
    "lat": "48.28587350490073",
    "lng": "14.285203442609037",
	"description": "Linz, Austria",
	"locality": "Linz HBF",
	"place_id": "xxxx",
	"timezone": "Europe/Zurich"
}"""

BASE_REST_CALL = """https://routenplaner.verkehrsauskunft.at/vao/restproxy/v1.6.0/{endpoint}?accessId={api_key}&format=json"""

def main(config):
    """main app function"""

    stop_info = get_stop_infos(config)
    #print(stop_info)

    return render.Root(
        child = render.Row(
            children = [
                render.WrappedText(
                    content = stop_info,
                    color = "#FFFFFF",
                    align = "left",
                    ),
            ]
        )
    )

def get_stop_infos(config):
    """gets the stop infos from the VAO API.
    Args:
        config: is a dict from the schema"""

    location = config.get("location", DEFAULT_LOCATION) 
    loc = json.decode(location)

    rest_call_stop_info = BASE_REST_CALL.format(
        endpoint = "location.nearbystops",
        api_key = config.get("key")
    ) + "&originCoordLat={lat}&originCoordLong={long}&maxNo{maxNo}".format(
        lat = loc["lat"],
        long = loc["lng"],
        maxNo = "1"
    )
    response = http.get(url = rest_call_stop_info)
    if response.status_code != 200:
        return "Request failed with status {statuscode}".format(
        statuscode = response.status_code
        )

    data = json.decode(response.body())
    print(data["stopLocationOrCoordLocation"])
    return "Hello"


def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "key",
                name = "API key",
                desc = "Paste your VAO API Key here",
                icon = "gear",
                default = "Paste your API key here"
            ),
            schema.Location(
                id = "location",
                name = "Your preferred stop",
                desc = "Search for any location to find the stop you want to use",
                icon = "locationDot",
            ),

        ],
    )