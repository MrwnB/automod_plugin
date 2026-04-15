import Category from "discourse/models/category";

const APPLICATIONS_CATEGORY_NAME = "applications";
const SUPPORTED_SUBCATEGORIES = new Set([
  "graduations",
  "apply for honoured",
  "apply for heroic",
  "become a master guardian",
  "become a grand guardian",
]);

function normalizeName(value) {
  return String(value || "").trim().toLowerCase();
}

export function isSupportedApplicationCategory(topic) {
  const category = Category.findById(topic.category_id);

  if (!category) {
    return false;
  }

  const categoryName = normalizeName(category.name);
  const parentName = normalizeName(category.parentCategory?.name);

  return (
    (!parentName && categoryName === APPLICATIONS_CATEGORY_NAME) ||
    (parentName === APPLICATIONS_CATEGORY_NAME &&
      SUPPORTED_SUBCATEGORIES.has(categoryName))
  );
}
