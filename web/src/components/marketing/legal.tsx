import type { ReactNode } from "react";

export function Legal({ sections }: { sections: Array<[string, ReactNode]> }) { return <div className="min-w-0 max-w-3xl space-y-7">{sections.map(([title, copy]) => <section className="min-w-0" key={title}><h2 className="text-xl font-bold text-[#201925]">{title}</h2><p className="mt-2 [overflow-wrap:anywhere] leading-7 text-[#5e5662]">{copy}</p></section>)}</div>; }
