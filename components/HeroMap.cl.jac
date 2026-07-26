"""Decorative SF backdrop behind the hero. No pan, no zoom, no clicks.

The scrim that keeps the headline readable over it lives in landing.css
(.hero::after) rather than here, so the copy and the map stay independent.
"""

import from "react-leaflet" { MapContainer, TileLayer }

def:pub HeroMap -> JsxElement {
    return
        <MapContainer
            className="hero-map"
            center={[37.7749, -122.4310]}
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
