import { createClient } from "@/utils/supabase/server";
import { TruckIcon, FileTextIcon, MapPinIcon } from "lucide-react";
import Link from "next/link";
import LoadMap from "@/components/LoadMap";

export default async function CustomerDashboard() {
  const supabase = await createClient();

  // Here we would normally filter by customer_id or user. To keep it simple, we fetch recent loads
  const { data: activeLoads } = await supabase
    .from("loads")
    .select("*")
    .in("status", ["dispatched", "picked_up", "in_transit"])
    .order("created_at", { ascending: false })
    .limit(5);

  const { data: pastLoads } = await supabase
    .from("loads")
    .select("*")
    .eq("status", "delivered")
    .order("created_at", { ascending: false })
    .limit(5);

  return (
    <div className="flex bg-slate-50 min-h-screen">
      {/* Sidebar */}
      <aside className="w-64 bg-white border-r">
        <div className="p-6">
          <h1 className="text-xl font-bold text-blue-600">Milow Portal</h1>
        </div>
        <nav className="p-4 space-y-2">
          <Link href="/" className="flex items-center gap-3 p-3 text-blue-700 bg-blue-50 rounded-lg">
            <TruckIcon className="w-5 h-5" />
            <span className="font-medium">Active Shipments</span>
          </Link>
          <Link href="/invoices" className="flex items-center gap-3 p-3 text-gray-600 hover:bg-slate-50 rounded-lg">
            <FileTextIcon className="w-5 h-5" />
            <span className="font-medium">Invoices & BOLs</span>
          </Link>
        </nav>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col">
        <header className="bg-white border-b py-4 px-8 flex justify-between items-center">
          <h2 className="text-2xl font-bold text-gray-800">Active Shipments</h2>
          <div className="flex items-center gap-4">
            <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold">
              C
            </div>
          </div>
        </header>

        <div className="flex-1 flex overflow-hidden">
          {/* List panel */}
          <div className="w-1/3 bg-white border-r overflow-y-auto">
            <div className="p-4 border-b bg-slate-50">
              <h3 className="font-semibold text-gray-700">In Transit ({activeLoads?.length || 0})</h3>
            </div>
            {activeLoads && activeLoads.length > 0 ? (
              <ul className="divide-y">
                {activeLoads.map((load) => (
                  <li key={load.id} className="p-4 hover:bg-slate-50 cursor-pointer transition">
                    <div className="flex justify-between items-start mb-2">
                      <span className="font-bold text-gray-900">#{load.trip_number || load.id.substring(0, 6)}</span>
                      <span className="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full uppercase tracking-wider font-semibold">
                        {load.status}
                      </span>
                    </div>
                    <div className="flex items-center gap-2 text-sm text-gray-500 mb-1">
                      <MapPinIcon className="w-4 h-4" />
                      Origin: {load.pickup_city || 'Unknown'}
                    </div>
                    <div className="flex items-center gap-2 text-sm text-gray-500">
                      <MapPinIcon className="w-4 h-4 text-green-600" />
                      Dest: {load.delivery_city || 'Unknown'}
                    </div>
                  </li>
                ))}
              </ul>
            ) : (
              <div className="p-8 text-center text-gray-500">
                No active shipments.
              </div>
            )}
          </div>

          {/* Map area */}
          <div className="flex-1 relative bg-slate-200">
            <LoadMap loads={activeLoads || []} />
          </div>
        </div>
      </main>
    </div>
  );
}
