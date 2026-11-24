const {timingSafeEqual} = require("node:crypto");

const hasVerifiedEmail = (auth) =>
  auth?.token?.email_verified === true;

const normalizeTeacherRegistration = (data) => {
  if (!data || typeof data !== "object") return null;
  const name = typeof data.name === "string" ? data.name.trim() : "";
  const department = typeof data.department === "string" ?
    data.department.trim() : "";
  const facultyCode = typeof data.facultyCode === "string" ?
    data.facultyCode.trim() : "";

  if (!name || name.length > 100 || !department ||
      department.length > 100 || !facultyCode || facultyCode.length > 128) {
    return null;
  }
  return {name, department, facultyCode};
};

const hasFacultyAccessCode = (providedCode, configuredCode) => {
  if (typeof providedCode !== "string" ||
      typeof configuredCode !== "string") {
    return false;
  }
  const provided = Buffer.from(providedCode, "utf8");
  const configured = Buffer.from(configuredCode, "utf8");
  return provided.length > 0 &&
    provided.length === configured.length &&
    timingSafeEqual(provided, configured);
};

const teacherProfileFields = ({name, department}) => ({
  role: "teacher",
  name,
  bio: "",
  photoUrl: "",
  department,
  skills: [],
  interests: [],
  domains: [],
  certificationUrls: [],
  followersCount: 0,
  followingCount: 0,
  resumeUrl: null,
  collegeName: "",
  preferredRole: "",
  experienceLevel: "",
  availability: "",
  preferredWorkingHours: "",
});

module.exports = {
  hasVerifiedEmail,
  hasFacultyAccessCode,
  normalizeTeacherRegistration,
  teacherProfileFields,
};
