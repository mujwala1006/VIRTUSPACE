const SKILL_CATEGORIES = {
  frontend: [
    "frontend", "front-end", "react", "angular", "vue", "javascript",
    "typescript", "html", "css", "web ui",
  ],
  backend: [
    "backend", "back-end", "node", "express", "java", "spring", "django",
    "flask", "api", "server", "sql", "database", "mongodb",
  ],
  mobile: [
    "mobile", "flutter", "dart", "android", "ios", "react native", "kotlin",
    "swift",
  ],
  "data/AI": [
    "data", "machine learning", "deep learning", "artificial intelligence",
    "ai", "ml", "tensorflow", "pytorch", "pandas", "analytics", "nlp",
    "python",
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
const asSet = (values = []) =>
  new Set(values.filter((value) => typeof value === "string")
      .map(normalize).filter(Boolean));

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

const categoriesFor = (values) =>
  new Set(values.map(skillCategory).filter(Boolean));

const overlapRatio = (matches, total) =>
  total === 0 ? 0 : matches / total;

const experienceScore = (level) => {
  switch (normalize(level || "")) {
    case "beginner":
    case "beginner (0-1 years)":
      return 0.45;
    case "intermediate":
    case "intermediate (1-3 years)":
      return 0.7;
    case "advanced":
    case "advanced (3+ years)":
      return 0.9;
    case "expert":
      return 1;
    default:
      return 0.5;
  }
};

const availabilityScore = (availability) => {
  switch (normalize(availability || "")) {
    case "available":
    case "actively looking":
      return 1;
    case "limited":
    case "limited availability":
      return 0.65;
    case "unavailable":
      return 0;
    default:
      return 0.5;
  }
};

/**
 * Deterministic recommendation score. Weights: skill 40, team balance 25,
 * interests 15, role 10, experience/availability 10.
 */
function scoreCandidate(userSkills, candidateSkills, requiredSkills = [], options = {}) {
  const candidate = options.candidate || {};
  const required = requiredSkills.filter((skill) => typeof skill === "string");
  const teamSkills = options.teamSkills || userSkills;
  const candidateSet = asSet(candidateSkills);
  const teamSet = asSet(teamSkills);
  const candidateCategories = categoriesFor(candidateSkills);
  const teamCategories = categoriesFor(teamSkills);
  const requiredCategories = categoriesFor(required);

  const missingSkills = required.filter((skill) => {
    return !teamSet.has(normalize(skill));
  });
  const skillTargets = missingSkills;
  const skillPoints = skillTargets.reduce((total, skill) => {
    if (candidateSet.has(normalize(skill))) return total + 1;
    const category = skillCategory(skill);
    return total + (category && candidateCategories.has(category) ? 0.55 : 0);
  }, 0);
  const skillFit = overlapRatio(skillPoints, skillTargets.length);

  const missingCategories = [...requiredCategories]
      .filter((category) => !teamCategories.has(category));
  const balanceFit = missingCategories.length > 0 ?
    overlapRatio(
        missingCategories.filter((category) =>
          candidateCategories.has(category)).length,
        missingCategories.length,
    ) :
    Math.min(
        [...candidateCategories].filter((category) =>
          !teamCategories.has(category)).length / 3,
        1,
    );

  const interests = asSet(candidate.interests || []);
  const projectInterests = asSet(options.projectDomains || []);
  const userInterests = asSet(options.userInterests || []);
  const interestTargets = new Set([...projectInterests, ...userInterests]);
  const interestFit = overlapRatio(
      [...interests].filter((interest) => interestTargets.has(interest)).length,
      interestTargets.size,
  );

  const expectedRoles = options.requiredRoles || [];
  const roleFit = expectedRoles.length > 0 ?
    (expectedRoles.some((role) =>
      normalize(candidate.preferredRole || "") === normalize(role)) ? 1 :
      expectedRoles.some((role) => candidateCategories.has(skillCategory(role))) ?
        0.6 : 0) :
    (candidate.preferredRole ? 0.6 : 0.3);

  const readinessFit = (
    experienceScore(candidate.experienceLevel) +
    availabilityScore(candidate.availability)
  ) / 2;

  const score = Math.max(0, Math.min(100, Math.round(
    skillFit * 40 +
    balanceFit * 25 +
    interestFit * 15 +
    roleFit * 10 +
    readinessFit * 10,
  )));

  const reasons = [];
  const covered = skillTargets.filter((skill) =>
    candidateSet.has(normalize(skill)));
  if (covered.length > 0) {
    reasons.push(`Covers missing project skills: ${covered.slice(0, 3).join(", ")}.`);
  }
  const complementary = missingCategories.filter((category) =>
    candidateCategories.has(category));
  if (complementary.length > 0) {
    reasons.push(`Adds a needed ${complementary.slice(0, 2).join(", ")} specialty.`);
  } else if (balanceFit > 0) {
    const extra = [...candidateCategories]
        .filter((category) => !teamCategories.has(category));
    if (extra.length > 0) {
      reasons.push(`Balances the team with ${extra.slice(0, 2).join(", ")} skills.`);
    }
  }
  if (interestFit > 0) reasons.push("Shares interests with this project.");
  if (roleFit >= 0.6 && candidate.preferredRole) {
    reasons.push(`Prefers the ${candidate.preferredRole} role.`);
  }
  if (candidate.availability) {
    reasons.push(
        `Availability: ${candidate.availability.toLowerCase()}${
          candidate.preferredWorkingHours ?
            ` (${candidate.preferredWorkingHours})` : ""
        }.`,
    );
  }
  if (candidate.experienceLevel) {
    reasons.push(`Experience: ${candidate.experienceLevel.toLowerCase()}.`);
  }
  if (reasons.length === 0) {
    reasons.push("Could bring a useful perspective to this project team.");
  }

  return {
    score,
    reason: reasons.join(" "),
    missingSkills: covered,
  };
}

function rankTeammates(userSkills, candidates, requiredSkills = [], limit = 10, options = {}) {
  const seen = new Set();
  return candidates
      .filter((candidate) => {
        if (typeof candidate.uid !== "string" || seen.has(candidate.uid)) {
          return false;
        }
        seen.add(candidate.uid);
        return true;
      })
      .map((candidate) => ({
        ...candidate,
        ...scoreCandidate(userSkills, candidate.skills, requiredSkills, {
          ...options,
          candidate,
        }),
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
