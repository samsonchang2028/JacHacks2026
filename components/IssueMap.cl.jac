"""Leaflet map of open civic issues.

divIcon markers rather than Leaflet's default PNG pins: the coral/teal tier
design wants CSS anyway, and it sidesteps the classic broken-marker-image bug
that bundlers cause.
"""

import from "react-leaflet" { MapContainer, TileLayer, Marker }
import from "leaflet" { divIcon }

def pin_icon(tier: str, selected: bool) -> any {
    size = 22 if tier == "full" else 15;
    cls = "q-pin " + tier;
    if selected {
        cls = cls + " selected";
    }
    return divIcon({
        "className": "",
        "html": "<i class='" + cls + "'></i>",
        "iconSize": [size, size],
        "iconAnchor": [size / 2, size / 2]
    });
}

# One marker. Its own component so the click handler can be a nested def --
# closing over the slug without needing a lambda.
def IssuePin(issue: any, selected: bool, on_select: any) -> JsxElement {
    def handle -> None {
        on_select(issue["slug"]);
    }

    return
        <Marker
            position={[issue["lat"], issue["lng"]]}
            icon={pin_icon(issue["tier"], selected)}
            eventHandlers={{"click": handle}}
        />;
}

def:pub IssueMap(issues: list, selected: str, on_select: any) -> JsxElement {
    return
        <MapContainer
            className="issue-map"
            center={[37.7749, -122.4394]}
            zoom={12}
            zoomControl={False}
            scrollWheelZoom={False}
        >
            <TileLayer
                url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
                attribution="&copy; OpenStreetMap contributors &copy; CARTO"
            />
            {[
                <IssuePin
                    key={i["slug"]}
                    issue={i}
                    selected={i["slug"] == selected}
                    on_select={on_select}
                />
                for i in issues
            ]}
        </MapContainer>;
}
