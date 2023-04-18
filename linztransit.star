load("render.star", "render")
load("schema.star", "schema")
load("http.star", "http")
load("encoding/json.star", "json")
load("time.star", "time")
load("cache.star", "cache")

DEFAULT_LOCATION = """{
    "lat": "48.185051",
    "lng": "16.377473",
	"description": "Wien, Austria",
	"locality": "Wien HBF",
	"place_id": "xxxx",
	"timezone": "Europe/Zurich"
}"""

UNDERLINE = [(0,0), (1,0)]

BASE_REST_CALL = """https://routenplaner.verkehrsauskunft.at/vao/restproxy/v1.6.0/{endpoint}?accessId={api_key}&format=json"""
#This is the dict which gets filled with infos from the rest calls


def main(config):
    """main app function"""

    response_dict = {
        "error": "No error",
        "stop_name": "No stop name",
        "stop_id": "No stop id",
        "next_departure_lines": ["No next departures"],
        "next_departure_times": ["No next departures"],
        "next_departure_dates": ["No next departures"],
        "next_departure_destinations": ["No next departures"],
        "next_departure_colors": ["No next departures"],
        "next_departure_times_until": ["No next departures"],
    }
    #Check if the response_dict is cached
    response_dict_cached = cache.get("response_dict")
    if response_dict_cached != None:
        print("Using cached response_dict")
        response_dict = json.decode(response_dict_cached)
    else:
        print("Performing new API calls")
        #Get the infos of the nearest stop
        response_dict = get_stop_infos(config, response_dict)

        #Get the next departures if stop was found
        if ((response_dict["error"] == "No error") and (response_dict["stop_id"] != "No stop id") and (response_dict["stop_name"] != "No stop name")):
            response_dict = get_next_departures(config, response_dict)

        #Calculate the time until the departures
        calculate_time_until(response_dict)

        cache.set("response_dict", str(response_dict), 9)

    response_dict = calculate_time_until(response_dict)

    print(response_dict["next_departure_colors"][0])
    #Render the results
    if response_dict["error"] != "No error":
        return render.Root(
            child = render.Row(
                children = [
                    render.WrappedText(
                        content = response_dict["error"],
                        color = "#FFFFFF",
                        align = "left",
                        )
                ]
            )
        )
    else:
        return render.Root(
            show_full_animation = True,
            child = render.Column(
                children = [
                    render_station(response_dict),
                    render_departure(response_dict, dep_number = 0),
                    render_departure(response_dict, dep_number = 1),
                    render_departure(response_dict, dep_number = 2),
                ],
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
    #print(rest_call_stop_info)

    response = http.get(url = rest_call_stop_info)
    if response.status_code != 200:
        response_dict["error"] = "Stopfinder request failed with status {statuscode}".format(
            statuscode = response.status_code
        )
        return response_dict

    data = json.decode(response.body())
    #if key 'stopLocationOrCoordLocation' is not in data, set response_dict["error"] to "No stop found within 1000 metres" and return
    if "stopLocationOrCoordLocation" not in data:
        response_dict["error"] = "No stop found within 1000 metres"
        return response_dict
    else:
        response_dict["stop_name"] = data['stopLocationOrCoordLocation'][0]['StopLocation']['name']
        response_dict["stop_id"] = data['stopLocationOrCoordLocation'][0]['StopLocation']['extId']
    #print(response_dict)

    return response_dict

def get_next_departures(config, response_dict):
    """gets the next departures from the VAO API.
    Args:
        config: is a dict from the schema"""

    rest_call_next_departures = BASE_REST_CALL.format(
        endpoint = "departureBoard",
        api_key = config.get("key")
    ) + "&id={stop_id}".format(
        stop_id = response_dict["stop_id"],
    )
    #print(rest_call_next_departures)

    response = http.get(url = rest_call_next_departures)
    if response.status_code != 200:
        response_dict["error"] = "Departurefinder request failed with status {statuscode}".format(
            statuscode = response.status_code
        )
        return response_dict

    data = json.decode(response.body())
    #print(data)
    #if key 'Departure' is not in data, set response_dict["error"] to "No departures found" and return
    if "Departure" not in data:
        response_dict["error"] = "No departures found"
        return response_dict
    else:
        response_dict["next_departure_lines"] = [entry["name"] for entry in data['Departure']]
        response_dict["next_departure_times"] = [entry["time"] for entry in data['Departure']]
        response_dict["next_departure_dates"] = [entry["date"] for entry in data['Departure']]
        response_dict["next_departure_colors"] = [entry["ProductAtStop"]["icon"]["backgroundColor"]["hex"] for entry in data['Departure']]
        response_dict["next_departure_destinations"] = [entry["direction"] for entry in data['Departure']]
    #print(response_dict)

    return response_dict

def calculate_time_until(response_dict):
    """calculates the time until the next departures.
    Args:
        response_dict: is a dict with the next departures"""

    #Get the current time
    now = time.now()
    time_from_response = response_dict["next_departure_dates"][0] + " " + response_dict["next_departure_times"][0]

    print(now)
    print(time_from_response)
    if time_from_response != "No next departures":
        deptime = time.parse_time(time_from_response, "%Y-%m-%d %H:%M:%S")
        print(deptime)



    return response_dict

def render_station(response_dict):
    return render.Stack(
                        children = [
                            render.Plot(width = 64, height = 8, x_lim = (0,1), y_lim=(0,8), data = UNDERLINE, color = "#FFFFFF"),
                            render.Marquee(
                                width = 64,
                                child = render.Text(content = response_dict["stop_name"], color = "FFFFFF"),
                            ),
                        ],
                    )

def render_departure(response_dict, dep_number):
    return render.Row(
                        children = [
                            render.Text(content="1", color="#099"),
                            render.Marquee(
                                width = 64,
                                child = render.Text(content = response_dict["next_departure_lines"][dep_number]
                                + " Destination: " + response_dict["next_departure_destinations"][dep_number],
                                color = response_dict["next_departure_colors"][dep_number]),
                            ),
                        ]
                    )


def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "key",
                name = "API key",
                desc = "Paste your VAO API Key here",
                icon = "gear",
                default = "6703c9bf-e119-44b4-84c5-dac1a92b827e"
            ),
            schema.Location(
                id = "location",
                name = "Your preferred stop",
                desc = "Search for any location to find the stop you want to use",
                icon = "locationDot",
            ),

        ],
    )
