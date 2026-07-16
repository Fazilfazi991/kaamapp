"use client";

import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Label, SelectField, TextInput } from "@/components/ui/form";
import { routes } from "@/config/routes";
import { maxCandidateSkills } from "@/features/candidate/constants";
import { saveCandidateSkills } from "@/features/candidate/server/actions";
import type { CandidateSkillRow, SkillCategoryRow, SkillRow } from "@/types/domain";

export function SkillsForm({
  categories,
  skills,
  selectedSkills,
  next = routes.candidateOnboardingLocation,
}: {
  categories: SkillCategoryRow[];
  skills: SkillRow[];
  selectedSkills: CandidateSkillRow[];
  next?: string;
}) {
  const firstSelected = selectedSkills[0]?.skills?.category_id ?? categories[0]?.id ?? "";
  const [categoryId, setCategoryId] = useState(firstSelected);
  const [selected, setSelected] = useState<string[]>(
    selectedSkills.map((item) => item.skill_id),
  );
  const [query, setQuery] = useState("");
  const [message, setMessage] = useState("");

  const visibleSkills = useMemo(() => {
    const lowered = query.toLowerCase();
    return skills.filter(
      (skill) =>
        skill.category_id === categoryId &&
        (!lowered || skill.name.toLowerCase().includes(lowered)),
    );
  }, [categoryId, query, skills]);

  function toggle(skillId: string) {
    setMessage("");
    if (selected.includes(skillId)) {
      setSelected(selected.filter((id) => id !== skillId));
      return;
    }
    if (selected.length >= maxCandidateSkills) {
      setMessage(`You can select a maximum of ${maxCandidateSkills} skills.`);
      return;
    }
    setSelected([...selected, skillId]);
  }

  return (
    <form action={saveCandidateSkills} className="grid gap-4">
      <input type="hidden" name="next" value={next} />
      <input type="hidden" name="skillIds" value={selected.join(",")} />
      <label className="grid gap-2">
        <Label>Main category</Label>
        <SelectField
          value={categoryId}
          onChange={(event) => {
            setCategoryId(event.target.value);
            setSelected([]);
            setQuery("");
          }}
        >
          {categories.map((category) => (
            <option value={category.id} key={category.id}>
              {category.name}
            </option>
          ))}
        </SelectField>
      </label>
      <label className="grid gap-2">
        <Label>Search skills</Label>
        <TextInput value={query} onChange={(event) => setQuery(event.target.value)} />
      </label>
      <p className="text-sm font-semibold text-[#514856]">
        Selected {selected.length} of {maxCandidateSkills}
      </p>
      {message ? <p className="text-sm font-semibold text-[#9a1744]">{message}</p> : null}
      <div className="grid gap-2 sm:grid-cols-2">
        {visibleSkills.map((skill) => {
          const active = selected.includes(skill.id);
          return (
            <button
              type="button"
              key={skill.id}
              onClick={() => toggle(skill.id)}
              className={`focus-ring rounded-lg border px-4 py-3 text-left text-sm font-semibold ${
                active
                  ? "border-[#e53670] bg-[#fff0f5] text-[#bc1f55]"
                  : "border-[#eadde3] bg-white text-[#342b38]"
              }`}
            >
              {active ? "✓ " : ""}
              {skill.name}
            </button>
          );
        })}
      </div>
      <div className="sticky bottom-16 flex gap-3 bg-white/95 py-3 sm:static">
        <Button type="submit" disabled={selected.length === 0}>
          Save and continue
        </Button>
      </div>
    </form>
  );
}
