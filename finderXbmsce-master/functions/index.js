const {initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const {rankTeammates} = require("./matching");

initializeApp();
const openAiApiKey = defineSecret("OPENAI_API_KEY");

exports.suggestTeammates = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to find teammates.");
  }
  if (!request.data || request.data.uid !== uid ||
      (request.data.projectId != null &&
        typeof request.data.projectId !== "string")) {
    throw new HttpsError(
        "invalid-argument",
        "A valid user and project are required.",
    );
  }

  const db = getFirestore();
  const userSnapshot = await db.collection("users").doc(uid).get();
  if (!userSnapshot.exists) {
    throw new HttpsError("not-found", "The user profile was not found.");
  }
  let projectId = request.data.projectId;
  if (typeof projectId !== "string") {
    if (userSnapshot.get("role") === "student") {
      const claim = await db.collection("users").doc(uid)
          .collection("activeBatch").doc("current").get();
      if (claim.exists) {
        const batch = await db.collection("batches")
            .doc(claim.get("batchId")).get();
        if (batch.exists && batch.get("status") === "active") {
          projectId = batch.get("projectId");
        }
      }
    } else {
      const ownedProjects = await db.collection("projects")
          .where("ownerUid", "==", uid)
          .limit(30)
          .get();
      const project = ownedProjects.docs.find((document) =>
        document.get("status") === "open" ||
        document.get("status") === "active");
      if (project) projectId = project.id;
    }
  }
  if (typeof projectId !== "string") {
    throw new HttpsError(
        "failed-precondition",
        "Join an active batch or create a project to get suggestions.",
    );
  }
  const projectSnapshot = await db.collection("projects").doc(projectId).get();
  if (!projectSnapshot.exists) {
    throw new HttpsError("not-found", "The project was not found.");
  }

  const project = projectSnapshot.data();
  let canAccess = project.ownerUid === uid;
  if (!canAccess && project.status === "open" && project.batchId == null) {
    canAccess = true;
  }
  if (!canAccess && typeof project.batchId === "string") {
    const batch = await db.collection("batches").doc(project.batchId).get();
    canAccess = batch.exists &&
      (batch.get("teacherUid") === uid ||
        (Array.isArray(batch.get("studentUids")) &&
          batch.get("studentUids").includes(uid)));
  }
  if (!canAccess) {
    throw new HttpsError(
        "permission-denied",
        "You must own the project, belong to its batch, or choose an open project.",
    );
  }

  const users = [];
  let page = await db.collection("users")
      .orderBy("__name__")
      .limit(500)
      .get();
  while (!page.empty) {
    users.push(...page.docs);
    if (page.size < 500) break;
    page = await db.collection("users")
        .orderBy("__name__")
        .startAfter(page.docs[page.docs.length - 1])
        .limit(500)
        .get();
  }
  const candidates = users
      .filter((document) => document.id !== uid)
      .map((document) => {
        const profile = document.data();
        return {
          uid: document.id,
          name: typeof profile.name === "string" ? profile.name : "FinderX user",
          role: typeof profile.role === "string" ? profile.role : "student",
          department: typeof profile.department === "string" ?
            profile.department : "",
          photoUrl: typeof profile.photoUrl === "string" ?
            profile.photoUrl : "",
          skills: Array.isArray(profile.skills) ?
            profile.skills.filter((skill) => typeof skill === "string") : [],
        };
      });

  return {
    suggestions: rankTeammates(
        Array.isArray(userSnapshot.get("skills")) ?
          userSnapshot.get("skills").filter((skill) => typeof skill === "string") : [],
        candidates,
        Array.isArray(project.requiredSkills) ?
          project.requiredSkills.filter((skill) => typeof skill === "string") : [],
        10,
    ),
  };
});

exports.inviteTeammate = onCall(async (request) => {
  const fromUid = request.auth?.uid;
  const {toUid, projectId} = request.data || {};
  if (!fromUid) {
    throw new HttpsError("unauthenticated", "Sign in to send an invitation.");
  }
  if (typeof toUid !== "string" || typeof projectId !== "string" ||
      toUid === fromUid) {
    throw new HttpsError("invalid-argument", "Choose a valid teammate.");
  }

  const db = getFirestore();
  const [projectSnapshot, targetSnapshot] = await Promise.all([
    db.collection("projects").doc(projectId).get(),
    db.collection("users").doc(toUid).get(),
  ]);
  if (!projectSnapshot.exists || !targetSnapshot.exists) {
    throw new HttpsError("not-found", "The project or teammate was not found.");
  }
  const project = projectSnapshot.data();
  let canInvite = project.ownerUid === fromUid;
  if (!canInvite && project.status === "open" && project.batchId == null) {
    canInvite = true;
  }
  let batchId = null;
  if (typeof project.batchId === "string") {
    const batch = await db.collection("batches").doc(project.batchId).get();
    if (batch.exists &&
        (batch.get("teacherUid") === fromUid ||
          (Array.isArray(batch.get("studentUids")) &&
            batch.get("studentUids").includes(fromUid)))) {
      canInvite = true;
      batchId = project.batchId;
    }
  }
  if (!canInvite) {
    throw new HttpsError(
        "permission-denied",
        "Only the project owner or a batch member can invite teammates.",
    );
  }

  const notificationId = `teammate_invite_${projectId}_${toUid}`;
  const notificationRef = db.collection("notifications").doc(notificationId);
  const sent = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(notificationRef);
    if (existing.exists) return false;
    transaction.create(notificationRef, {
      toUid,
      fromUid,
      type: "teammate_invite",
      refId: projectId,
      ...(batchId == null ? {} : {batchId}),
      createdAt: FieldValue.serverTimestamp(),
      read: false,
    });
    return true;
  });
  return {sent};
});

exports.chatbot = onCall(
    {secrets: [openAiApiKey], timeoutSeconds: 60},
    async (request) => {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Sign in to use the chatbot.");
      }
      const message = request.data?.message;
      if (typeof message !== "string" ||
          message.trim().length === 0 || message.trim().length > 2000) {
        throw new HttpsError(
            "invalid-argument",
            "Enter a message up to 2,000 characters.",
        );
      }

      const db = getFirestore();
      const now = Date.now();
      const rateRef = db.collection("aiChatRateLimits").doc(uid);
      const rateLimit = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(rateRef);
        const resetAt = snapshot.exists ? snapshot.get("resetAt")?.toMillis() : 0;
        const previousCount = snapshot.exists ? snapshot.get("count") : 0;
        const count = resetAt > now ? previousCount : 0;
        if (count >= 20) return false;
        transaction.set(rateRef, {
          count: count + 1,
          resetAt: count === 0 ? new Date(now + 60 * 60 * 1000) :
            snapshot.get("resetAt"),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!rateLimit) {
        throw new HttpsError(
            "resource-exhausted",
            "Chat limit reached. Try again after the hourly reset.",
        );
      }

      const messagesRef = db.collection("users").doc(uid)
          .collection("aiChatMessages");
      const historySnapshot = await messagesRef
          .orderBy("createdAt", "desc")
          .limit(12)
          .get();
      const history = historySnapshot.docs.reverse().map((document) => ({
        role: document.get("role"),
        content: document.get("content"),
      })).filter((item) =>
        (item.role === "user" || item.role === "assistant") &&
        typeof item.content === "string");

      let response;
      try {
        response = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${openAiApiKey.value()}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            temperature: 0.4,
            max_tokens: 700,
            messages: [
              {
                role: "system",
                content: "You are FinderX Assistant. Help users understand FinderX profiles, skills, faculty, projects, teammate invitations, batches, tasks, and batch chat. Give concise, practical guidance about using the app. Do not claim to access or change a user's account, send invitations, or view private data. Never request passwords, API keys, or sensitive personal information. If asked unrelated questions, briefly redirect to FinderX.",
              },
              ...history,
              {role: "user", content: message.trim()},
            ],
          }),
          signal: AbortSignal.timeout(45000),
        });
      } catch (error) {
        logger.error("FinderX chatbot provider request failed.", {
          uid,
          error: error.message,
        });
        throw new HttpsError(
            "unavailable",
            "The assistant is temporarily unavailable. Please try again.",
        );
      }
      if (!response.ok) {
        logger.error("FinderX chatbot provider returned an error.", {
          uid,
          status: response.status,
        });
        throw new HttpsError(
            "unavailable",
            "The assistant is temporarily unavailable. Please try again.",
        );
      }
      const payload = await response.json();
      const answer = payload.choices?.[0]?.message?.content;
      if (typeof answer !== "string" || answer.trim().length === 0) {
        logger.error("FinderX chatbot provider returned an empty answer.", {uid});
        throw new HttpsError(
            "unavailable",
            "The assistant did not return a response. Please try again.",
        );
      }

      const batch = db.batch();
      const timestamp = Date.now();
      batch.create(messagesRef.doc(), {
        role: "user",
        content: message.trim(),
        createdAt: new Date(timestamp),
      });
      batch.create(messagesRef.doc(), {
        role: "assistant",
        content: answer.trim(),
        createdAt: new Date(timestamp + 1),
      });
      await batch.commit();
      return {answer: answer.trim()};
    },
);

exports.createBatch = onCall(async (request) => {
  const teacherUid = request.auth?.uid;
  if (!teacherUid) {
    throw new HttpsError("unauthenticated", "Sign in to create a batch.");
  }

  const {batchId, projectId, studentUids} = request.data || {};
  if (typeof batchId !== "string" || batchId.length === 0 ||
      typeof projectId !== "string" || projectId.length === 0 ||
      !Array.isArray(studentUids) || studentUids.length < 4 ||
      studentUids.some((uid) => typeof uid !== "string" || uid.length === 0) ||
      new Set(studentUids).size !== studentUids.length) {
    throw new HttpsError(
        "invalid-argument",
        "Choose a project and at least four distinct students.",
    );
  }

  const db = getFirestore();
  const batchRef = db.collection("batches").doc(batchId);
  const teacherRef = db.collection("users").doc(teacherUid);
  const projectRef = db.collection("projects").doc(projectId);
  const statsRef = db.collection("facultyStats").doc(teacherUid);
  const studentRefs = studentUids.map((uid) =>
    db.collection("users").doc(uid));
  const claimRefs = studentUids.map((uid) =>
    db.collection("users").doc(uid)
        .collection("activeBatch").doc("current"));

  await db.runTransaction(async (transaction) => {
    const batchSnapshot = await transaction.get(batchRef);
    const teacherSnapshot = await transaction.get(teacherRef);
    const projectSnapshot = await transaction.get(projectRef);
    const statsSnapshot = await transaction.get(statsRef);
    const students = [];
    const claims = [];
    for (let index = 0; index < studentRefs.length; index++) {
      students.push(await transaction.get(studentRefs[index]));
      claims.push(await transaction.get(claimRefs[index]));
    }

    if (batchSnapshot.exists) {
      throw new HttpsError("already-exists", "This batch already exists.");
    }
    if (!teacherSnapshot.exists || teacherSnapshot.get("role") !== "teacher") {
      throw new HttpsError(
          "permission-denied",
          "Only a teacher can create a batch.",
      );
    }
    const project = projectSnapshot.data();
    if (!project || project.ownerUid !== teacherUid ||
        project.batchId != null || project.status !== "open") {
      throw new HttpsError(
          "failed-precondition",
          "Choose an available project owned by you.",
      );
    }
    for (let index = 0; index < students.length; index++) {
      if (!students[index].exists ||
          students[index].get("role") !== "student") {
        throw new HttpsError(
            "invalid-argument",
            "Every selected member must be a student.",
        );
      }
      if (claims[index].exists) {
        throw new HttpsError(
            "failed-precondition",
            "One or more selected students are already in an active batch.",
        );
      }
    }

    const startDate = new Date();
    const monthIndex = startDate.getUTCMonth() + 3;
    const endYear = startDate.getUTCFullYear() +
      Math.floor(monthIndex / 12);
    const endMonth = monthIndex % 12;
    const lastDay = new Date(Date.UTC(endYear, endMonth + 1, 0)).getUTCDate();
    const endDate = new Date(Date.UTC(
        endYear,
        endMonth,
        Math.min(startDate.getUTCDate(), lastDay),
        startDate.getUTCHours(),
        startDate.getUTCMinutes(),
        startDate.getUTCSeconds(),
        startDate.getUTCMilliseconds(),
    ));
    const batch = {
      teacherUid,
      studentUids,
      projectId,
      startDate,
      endDate,
      status: "active",
    };

    transaction.create(batchRef, batch);
    transaction.update(projectRef, {
      batchId,
      status: "active",
      doneTaskCount: 0,
      totalTaskCount: 0,
    });
    const existingStudents = statsSnapshot.exists ?
      statsSnapshot.get("activeStudentUids") : [];
    transaction.set(statsRef, {
      teacherUid,
      activeStudentUids: [...new Set([
        ...(Array.isArray(existingStudents) ? existingStudents : []),
        ...studentUids,
      ])],
      lastBatchId: batchId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    for (let index = 0; index < studentUids.length; index++) {
      transaction.create(claimRefs[index], {
        batchId,
        teacherUid,
        endsAt: endDate,
      });
    }
  });

  return {batchId};
});

const notificationCopy = (type, senderName) => {
  switch (type) {
    case "follow":
      return {title: "New follower", body: `${senderName} followed you.`};
    case "interest":
      return {title: "New project interest", body: `${senderName} is interested in your profile.`};
    case "batch_invite":
      return {title: "Batch invitation", body: `${senderName} sent you a batch invitation.`};
    case "teammate_invite":
      return {title: "Project invitation", body: `${senderName} invited you to collaborate.`};
    case "task":
      return {title: "Project update", body: `${senderName} updated a task.`};
    case "batch_completed":
      return {title: "Batch completed", body: `${senderName} completed your project batch.`};
    default:
      return {title: "FinderX notification", body: `${senderName} sent you an update.`};
  }
};

exports.sendNotificationPush = onDocumentCreated(
    "notifications/{notificationId}",
    async (event) => {
      const notification = event.data?.data();
      if (!notification ||
          typeof notification.toUid !== "string" ||
          typeof notification.fromUid !== "string") {
        logger.error("Notification is missing its sender or recipient.", {
          notificationId: event.params.notificationId,
        });
        return;
      }

      const db = getFirestore();
      const recipient = await db.collection("users").doc(notification.toUid).get();
      if (!recipient.exists) {
        logger.warn("Notification recipient profile does not exist.", {
          toUid: notification.toUid,
        });
        return;
      }

      const tokenSnapshot = await db
          .collection("users")
          .doc(notification.toUid)
          .collection("fcmTokens")
          .get();
      const tokenDocuments = tokenSnapshot.docs.filter((document) => {
        const token = document.get("token") || document.id;
        return typeof token === "string" && token.length > 0;
      });
      const tokens = tokenDocuments.map(
          (document) => document.get("token") || document.id,
      );
      if (tokens.length === 0) {
        logger.info("Recipient has no registered push tokens.", {
          toUid: notification.toUid,
        });
        return;
      }

      const sender = await db.collection("users").doc(notification.fromUid).get();
      const senderName = sender.exists ? sender.get("name") || "Someone" : "Someone";
      const copy = notificationCopy(notification.type, senderName);
      const notificationType = typeof notification.type === "string" ?
        notification.type : "";
      const invalidTokenDeletes = [];
      let successCount = 0;
      let failureCount = 0;
      for (let offset = 0; offset < tokens.length; offset += 500) {
        const batchTokens = tokens.slice(offset, offset + 500);
        const response = await getMessaging().sendEachForMulticast({
          tokens: batchTokens,
          notification: copy,
          data: {
            notificationId: event.params.notificationId,
            type: notificationType,
            fromUid: notification.fromUid,
          },
          android: {
            priority: "high",
          },
          apns: {
            payload: {aps: {sound: "default"}},
          },
        });
        successCount += response.successCount;
        failureCount += response.failureCount;
        response.responses.forEach((result, index) => {
          if (result.success) return;
          if (result.error?.code === "messaging/registration-token-not-registered") {
            invalidTokenDeletes.push(tokenDocuments[offset + index].ref.delete());
            return;
          }
          logger.error("Failed to deliver a push notification.", {
            toUid: notification.toUid,
            error: result.error?.message || "Unknown FCM error",
          });
        });
      }
      await Promise.all(invalidTokenDeletes);
      logger.info("Push notification delivery finished.", {
        toUid: notification.toUid,
        successCount,
        failureCount,
      });
    },
);

exports.completeExpiredBatches = onSchedule(
    "every 60 minutes",
    async () => {
      const db = getFirestore();
      const now = new Date();
      const dueBatches = await db.collection("batches")
          .where("status", "==", "active")
          .where("endDate", "<=", now)
          .get();

      for (const candidate of dueBatches.docs) {
        await db.runTransaction(async (transaction) => {
          const batchSnapshot = await transaction.get(candidate.ref);
          if (!batchSnapshot.exists) return;
          const batch = batchSnapshot.data();
          const endDate = batch.endDate?.toDate ?
            batch.endDate.toDate() : batch.endDate;
          if (batch.status !== "active" ||
              !(endDate instanceof Date) ||
              endDate > now) {
            return;
          }
          const studentUids = Array.isArray(batch.studentUids) ?
            batch.studentUids.filter((uid) => typeof uid === "string") : [];
          const claimRefs = studentUids.map((uid) => db.collection("users")
              .doc(uid).collection("activeBatch").doc("current"));
          const claims = [];
          for (const claimRef of claimRefs) {
            claims.push(await transaction.get(claimRef));
          }
          const projectRef = db.collection("projects").doc(batch.projectId);
          const project = await transaction.get(projectRef);

          transaction.update(candidate.ref, {status: "completed"});
          for (let index = 0; index < claims.length; index++) {
            if (claims[index].exists &&
                claims[index].get("batchId") === candidate.id) {
              transaction.delete(claimRefs[index]);
            }
          }
          if (project.exists && project.get("batchId") === candidate.id) {
            transaction.update(projectRef, {
              batchId: null,
              status: "open",
            });
          }
        });
      }

      const teacherUids = [...new Set(dueBatches.docs
          .map((document) => document.get("teacherUid"))
          .filter((uid) => typeof uid === "string"))];
      for (const teacherUid of teacherUids) {
        const activeBatches = await db.collection("batches")
            .where("teacherUid", "==", teacherUid)
            .where("status", "==", "active")
            .get();
        const activeStudentUids = [...new Set(activeBatches.docs.flatMap(
            (document) => Array.isArray(document.get("studentUids")) ?
              document.get("studentUids").filter(
                  (uid) => typeof uid === "string",
              ) : [],
        ))];
        await db.collection("facultyStats").doc(teacherUid).set({
          activeStudentUids,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      logger.info("Expired batch scan finished.", {
        candidates: dueBatches.size,
      });
    },
);

exports.notifyBatchCompletion = onDocumentUpdated(
    {document: "batches/{batchId}", retry: true},
    async (event) => {
      const before = event.data?.before.data();
      const after = event.data?.after.data();
      if (!before || !after ||
          before.status !== "active" ||
          after.status !== "completed") {
        return;
      }
      if (typeof after.teacherUid !== "string" ||
          typeof event.params.batchId !== "string") {
        throw new Error("Completed batch is missing its teacher or ID.");
      }

      const db = getFirestore();
      const recipients = [...new Set([
        after.teacherUid,
        ...(Array.isArray(after.studentUids) ? after.studentUids : []),
      ])].filter((uid) => typeof uid === "string");
      const notificationWrites = recipients.map((uid) => {
        const notificationId =
          `batch_completed_${event.params.batchId}_${uid}`;
        const ref = db.collection("notifications").doc(notificationId);
        return ref.create({
          toUid: uid,
          fromUid: after.teacherUid,
          type: "batch_completed",
          refId: event.params.batchId,
          createdAt: new Date(),
          read: false,
        }).catch((error) => {
          if (error.code === 6 || error.code === "already-exists") return;
          throw error;
        });
      });
      await Promise.all(notificationWrites);
      logger.info("Batch completion notifications created.", {
        batchId: event.params.batchId,
        recipientCount: recipients.length,
      });
    },
);

exports.updateProjectTaskProgress = onDocumentWritten(
    "batches/{batchId}/tasks/{taskId}",
    async (event) => {
      const db = getFirestore();
      const batchRef = db.collection("batches").doc(event.params.batchId);
      const batch = await batchRef.get();
      if (!batch.exists) {
        logger.error("Task belongs to a missing batch.", {
          batchId: event.params.batchId,
        });
        return;
      }
      const projectId = batch.get("projectId");
      if (typeof projectId !== "string") {
        throw new Error(`Batch ${event.params.batchId} has no project ID.`);
      }
      const tasks = await batchRef.collection("tasks").get();
      const totalTaskCount = tasks.size;
      const doneTaskCount = tasks.docs.filter(
          (document) => document.get("status") === "done",
      ).length;
      await db.collection("projects").doc(projectId).update({
        doneTaskCount,
        totalTaskCount,
      });
    },
);
