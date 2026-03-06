import { createClient } from "@/utils/supabase/server";
import { TruckIcon, FileTextIcon, DownloadIcon } from "lucide-react";
import Link from "next/link";

export default async function InvoicesPage() {
    const supabase = await createClient();

    // Fetch delivered loads which would have associated invoices and delivery documents
    const { data: pastLoads } = await supabase
        .from("loads")
        .select("*")
        .eq("status", "delivered")
        .order("created_at", { ascending: false })
        .limit(10);

    return (
        <div className="flex bg-slate-50 min-h-screen">
            {/* Sidebar */}
            <aside className="w-64 bg-white border-r">
                <div className="p-6">
                    <h1 className="text-xl font-bold text-blue-600">Milow Portal</h1>
                </div>
                <nav className="p-4 space-y-2">
                    <Link href="/" className="flex items-center gap-3 p-3 text-gray-600 hover:bg-slate-50 rounded-lg">
                        <TruckIcon className="w-5 h-5" />
                        <span className="font-medium">Active Shipments</span>
                    </Link>
                    <Link href="/invoices" className="flex items-center gap-3 p-3 text-blue-700 bg-blue-50 rounded-lg">
                        <FileTextIcon className="w-5 h-5" />
                        <span className="font-medium">Invoices & BOLs</span>
                    </Link>
                </nav>
            </aside>

            {/* Main Content */}
            <main className="flex-1 flex flex-col">
                <header className="bg-white border-b py-4 px-8 flex justify-between items-center">
                    <h2 className="text-2xl font-bold text-gray-800">Invoices & Documents</h2>
                    <div className="flex items-center gap-4">
                        <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold">
                            C
                        </div>
                    </div>
                </header>

                <div className="flex-1 p-8 overflow-y-auto">
                    <div className="bg-white rounded-xl shadow-sm border overflow-hidden">
                        <table className="w-full text-left border-collapse">
                            <thead>
                                <tr className="bg-slate-50 border-b">
                                    <th className="p-4 font-semibold text-gray-600">Trip Reference</th>
                                    <th className="p-4 font-semibold text-gray-600">Origin</th>
                                    <th className="p-4 font-semibold text-gray-600">Destination</th>
                                    <th className="p-4 font-semibold text-gray-600 text-right">Documents</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y">
                                {pastLoads && pastLoads.length > 0 ? (
                                    pastLoads.map((load) => (
                                        <tr key={load.id} className="hover:bg-slate-50 transition">
                                            <td className="p-4">
                                                <span className="font-bold text-gray-900">#{load.trip_number || load.id.substring(0, 8)}</span>
                                            </td>
                                            <td className="p-4 text-gray-700">{load.pickup_city || 'N/A'}</td>
                                            <td className="p-4 text-gray-700">{load.delivery_city || 'N/A'}</td>
                                            <td className="p-4">
                                                <div className="flex justify-end gap-2">
                                                    <button className="flex items-center gap-1 text-sm bg-white border border-gray-300 hover:bg-gray-50 text-gray-700 py-1.5 px-3 rounded-lg font-medium transition">
                                                        <DownloadIcon className="w-4 h-4" />
                                                        BOL
                                                    </button>
                                                    <button className="flex items-center gap-1 text-sm bg-blue-50 text-blue-700 hover:bg-blue-100 py-1.5 px-3 rounded-lg font-medium transition">
                                                        <DownloadIcon className="w-4 h-4" />
                                                        Invoice
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    ))
                                ) : (
                                    <tr>
                                        <td colSpan={4} className="p-8 text-center text-gray-500">
                                            No past shipments or documents available.
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            </main>
        </div>
    );
}
