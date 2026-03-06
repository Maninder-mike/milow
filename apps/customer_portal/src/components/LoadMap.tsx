"use client";

import { useState } from "react";
import Map, { Marker, Popup } from "react-map-gl";
import "mapbox-gl/dist/mapbox-gl.css";
import { TruckIcon } from "lucide-react";

export default function LoadMap({ loads }: { loads: any[] }) {
    const [selectedLoad, setSelectedLoad] = useState<any | null>(null);

    // Focus roughly on center of US if no loads, or center on the active loads
    const defaultViewState = {
        longitude: -95.7129,
        latitude: 37.0902,
        zoom: 4,
    };

    return (
        <div className="w-full h-full relative">
            <Map
                mapboxAccessToken={process.env.NEXT_PUBLIC_MAPBOX_TOKEN}
                initialViewState={defaultViewState}
                style={{ width: "100%", height: "100%" }}
                mapStyle="mapbox://styles/mapbox/light-v11"
            >
                {loads?.map((load) => {
                    // Fallback to origin coordinates if current location not available
                    const lat = load.current_lat || load.pickup_lat;
                    const lng = load.current_lng || load.pickup_lng;

                    if (!lat || !lng) return null;

                    return (
                        <Marker
                            key={load.id}
                            longitude={lng}
                            latitude={lat}
                            anchor="bottom"
                            onClick={(e) => {
                                e.originalEvent.stopPropagation();
                                setSelectedLoad(load);
                            }}
                        >
                            <div className="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center text-white cursor-pointer shadow-lg outline outline-2 outline-white transform hover:scale-110 transition">
                                <TruckIcon className="w-4 h-4" />
                            </div>
                        </Marker>
                    );
                })}

                {selectedLoad && (
                    <Popup
                        longitude={selectedLoad.current_lng || selectedLoad.pickup_lng}
                        latitude={selectedLoad.current_lat || selectedLoad.pickup_lat}
                        anchor="bottom"
                        offset={32}
                        onClose={() => setSelectedLoad(null)}
                        className="rounded-xl overflow-hidden shadow-xl"
                    >
                        <div className="p-3 w-48 rounded-lg">
                            <h4 className="font-bold text-gray-900 border-b pb-2 mb-2">Trip #{selectedLoad.trip_number || selectedLoad.id.substring(0, 6)}</h4>
                            <p className="text-sm text-gray-700"><strong>Status:</strong> <span className="uppercase text-xs font-bold text-blue-600 bg-blue-50 px-2 py-1 rounded">{selectedLoad.status}</span></p>
                            <p className="text-sm text-gray-700 mt-2"><strong>Origin:</strong> {selectedLoad.pickup_city}</p>
                            <p className="text-sm text-gray-700"><strong>Dest:</strong> {selectedLoad.delivery_city}</p>
                        </div>
                    </Popup>
                )}
            </Map>
        </div>
    );
}
