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

    #This is the dict which gets filled with infos from the rest calls
    response_dict = {
        "error": "No error",
        "stop_name": "No stop name",
        "stop_id": "No stop id",
    }

    #Get the infos of the nearest stop
    stop_info = get_stop_infos(config, response_dict)
    #print(stop_info)

    if response_dict["error"] != "No error":
        return render.Root(
            child = render.Row(
                children = [
                    render.WrappedText(
                        content = stop_info["error"],
                        color = "#FFFFFF",
                        align = "left",
                        ),
                ]
            )
        )
    else:
        return render.Root(
            child = render.Row(
                children = [
                    render.WrappedText(
                        content = stop_info["stop_name"],
                        color = "#FFFFFF",
                        align = "left",
                        ),
                    render.WrappedText(
                        content = stop_info["stop_id"],
                        color = "#FFFFFF",
                        align = "right",
                        ),
                ]
            )
        )

def get_stop_infos(config, response_dict):
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
        response_dict["error"] = "Request failed with status {statuscode}".format(
            statuscode = response.status_code
        )
        return response_dict

    data = json.decode(response.body())
    response_dict["stop_name"] = data['stopLocationOrCoordLocation'][0]['StopLocation']['name']
    response_dict["stop_id"] = data['stopLocationOrCoordLocation'][0]['StopLocation']['extId']
    print(response_dict)

    return response_dict


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
