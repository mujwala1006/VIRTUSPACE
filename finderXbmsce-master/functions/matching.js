const SKILL_CATEGORIES = {
  frontend: [
    "frontend", "front-end", "react", "angular", "vue", "javascript",
    "typescript", "html", "css", "web ui",
  ],
  backend: [
    "backend", "back-end", "node", "express", "java", "spring", "django",
    "flask", "api", "server", "sql", "database",
  ],
  mobile: [
    "mobile", "flutter", "dart", "android", "ios", "react native", "kotlin",
    "swift",
  ],
  "data/AI": [
    "data", "machine learning", "deep learning", "artificial intelligence",
    "ai", "ml", "tensorflow", "pytorch", "pandas", "analytics", "nlp",
  ],
  design: [
    "design", "ui/ux", "ux", "ui", "figma", "wireframe", "prototyping",
    "graphic",
  ],
  hardware: [
    "hardware", "arduino", "raspberry pi", "embedded", "iot", "electronics",
    "robotics", "circuit", "microcontroller",
  ],
};

const normalize = (value) => value.trim().toLowerCase().replace(/\s+/g, " ");

function skillCategory(skill) {
  const normalized = normalize(skill);
  for (const [category, keywords] of Object.entries(SKILL_CATEGORIES)) {
    if (keywords.some((keyword) => {
      const escaped = keyword.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      return new RegExp(`(^|[^a-z0-9])${escaped}([^a-z0-9]|$)`, "i")
          .test(normalized);
    })) {
      return category;
    }
  }
  return null;
}

function scoreCandidate(userSkills, candidateSkills, requiredSkills = []) {
  const userSet = new Set(userSkills.map(normalize));
  const candidateSet = new Set(candidateSkills.map(normalize));
  const userCategories = new Set(userSkills.map(skillCategory).filter(Boolean));
  const candidateCategories =
    new Set(candidateSkills.map(skillCategory).filter(Boolean));
  const requiredCategories =
    new Set(requiredSkills.map(skillCategory).filter(Boolean));

  const matchingRequired = requiredSkills.filter(
      (skill) => candidateSet.has(normalize(skill)),
  );
  const coveredCategories = [...requiredCategories].filter(
      (category) => candidateCategories.has(category),
  );
  const complementaryRequiredCategories = coveredCategories.filter(
      (category) => !userCategories.has(category),
  );
  const complementaryCategories = [...candidateCategories].filter(
      (category) => !userCategories.has(category),
  );
  const overlap = [...candidateSet].filter((skill) => userSet.has(skill)).length;
  const unionSize = new Set([...userSet, ...candidateSet]).size;
  const similarity = unionSize === 0 ? 0 : overlap / unionSize;
  const identicalSkills = userSet.size === candidateSet.size &&
      [...userSet].every((skill) => candidateSet.has(skill));

  const score = Math.max(0, Math.min(100,
    matchingRequired.length * 22 +
    coveredCategories.length * 10 +
    complementaryRequiredCategories.length * 16 +
    Math.min(complementaryCategories.length, 3) * 5 -
    Math.round(similarity * 28) -
    (identicalSkills ? 24 : 0),
  ));

  let reason;
  if (matchingRequired.length > 0) {
    reason = `Covers project needs: ${matchingRequired.slice(0, 3).join(", ")}.`;
  } else if (complementaryRequiredCategories.length > 0) {
    reason = `Adds complementary ${complementaryRequiredCategories.join(", ")} skills for this project.`;
  } else if (complementaryCategories.length > 0) {
    reason = `Brings complementary ${complementaryCategories.slice(0, 3).join(", ")} skills.`;
  } else if (identicalSkills) {
    reason = "Your skill sets are very similar; consider a different specialty.";
  } else {
    reason = "Could bring a useful perspective to your project team.";
  }

  return {score, reason};
}

function rankTeammates(userSkills, candidates, requiredSkills = [], limit = 10) {
  return candidates
      .map((candidate) => ({
        ...candidate,
        ...scoreCandidate(userSkills, candidate.skills, requiredSkills),
      }))
      .sort((left, right) =>
        right.score - left.score || left.name.localeCompare(right.name))
      .slice(0, limit);
}

module.exports = {
  SKILL_CATEGORIES,
  rankTeammates,
  scoreCandidate,
  skillCategory,
};
