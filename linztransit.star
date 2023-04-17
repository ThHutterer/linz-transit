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

        cache.set("response_dict", str(response_dict), 9)

    response_dict = calculate_time_until(response_dict)

    #print(response_dict)
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
                    render.Row(
                        children = [
                        render.Box(
                            color = "FFFFFF",
                            width = 10,
                            height = 10,
                            ),
                        render.Marquee(
                            width = 64,
                            child = render.Text(content = response_dict["stop_name"], color = "FFFFFF"),
                            ),
                        ]
                    ),
                    render.Marquee(
                        width = 64,
                        child = render.Text(content = response_dict["next_departure_lines"][0]
                         + " Destination: " + response_dict["next_departure_destinations"][0],
                         color = response_dict["next_departure_colors"][0]),
                        ),
                    render.Marquee(
                        width = 64,
                        child = render.Text(content = response_dict["next_departure_lines"][1]
                         + " Destination: " + response_dict["next_departure_destinations"][1],
                         color = response_dict["next_departure_colors"][1]),
                        ),
                    render.Marquee(
                        width = 64,
                        child = render.Text(content = response_dict["next_departure_lines"][3]
                         + " Destination: " + response_dict["next_departure_destinations"][3],
                         color = response_dict["next_departure_colors"][3]),
                        ),
                ],
            ),
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
    #deptime = time.parse_time("2000-03-11T11:27:00.00Z")
    print(now)
    print(response_dict["next_departure_times"][0])

    #Calculate the time until the next departures
    #for i in range(0, len(response_dict["next_departure_times"])):
        #Get the time of the next departure
        #next_departure_time = response_dict["next_departure_times"][i]
        #Calculate the time until the next departure
        #time_until = datetime.strptime(next_departure_time, "%H:%M") - datetime.strptime(now, "%H:%M")
        #Convert the time until the next departure to a string
        #time_until = str(time_until)
        #Remove the seconds from the string
        #time_until = time_until[:-3]
        #Add the time until the next departure to the response_dict
        #response_dict["next_departure_times_until"].append(time_until)

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
