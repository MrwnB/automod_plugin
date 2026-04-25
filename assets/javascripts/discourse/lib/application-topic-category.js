import Category from "discourse/models/category";

const APPLICATIONS_CATEGORY_NAME = "applications";
const STANDALONE_CATEGORIES = new Map([
  ["join us", "join_application"],
  ["join-us", "join_application"],
]);
const SUPPORTED_SUBCATEGORIES = new Map([
  ["graduations", "graduations"],
  ["apply for honoured", "honoured_guardian"],
  ["apply for heroic", "heroic_guardian"],
  ["become a master guardian", "master_guardian"],
  ["become a grand guardian", "grand_guardian"],
]);

function normalizeName(value) {
  return String(value || "")
    .trim()
    .toLowerCase();
}

function categoryIdentifiers(category) {
  return [category?.name, category?.slug]
    .map((value) => normalizeName(value))
    .filter(Boolean);
}

function categoryKeyFor(identifiers, categoryKeys) {
  for (const identifier of identifiers) {
    if (categoryKeys.has(identifier)) {
      return categoryKeys.get(identifier);
    }
  }
}

export function applicationCategoryKey(topic) {
  const category = Category.findById(topic.category_id);

  if (!category) {
    return;
  }

  const identifiers = categoryIdentifiers(category);
  const parentIdentifiers = categoryIdentifiers(category.parentCategory);

  if (parentIdentifiers.includes(APPLICATIONS_CATEGORY_NAME)) {
    return categoryKeyFor(identifiers, SUPPORTED_SUBCATEGORIES);
  }

  if (parentIdentifiers.length === 0) {
    return categoryKeyFor(identifiers, STANDALONE_CATEGORIES);
  }
}

export function isSupportedApplicationCategory(topic) {
  return Boolean(applicationCategoryKey(topic));
}
