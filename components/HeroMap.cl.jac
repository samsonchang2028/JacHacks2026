"""Decorative real map behind the hero. No pan, no zoom, no clicks.

The rings and pin sit on top as CSS overlays (see .decision-ring / .impact-ring /
.map-pin) because the view never moves -- no need to project them geographically.
"""

import from "react-leaflet" { MapContainer, TileLayer }

def:pub HeroMap -> JsxElement {
    return
        <MapContainer
            className="hero-map"
            center={[37.7935, -122.4085]}
            zoom={13}
            zoomControl={False}
            dragging={False}
            scrollWheelZoom={False}
            doubleClickZoom={False}
            touchZoom={False}
            boxZoom={False}
            keyboard={False}
        >
            <TileLayer
                url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
                attribution="&copy; OpenStreetMap contributors &copy; CARTO"
            />
        </MapContainer>;
}
