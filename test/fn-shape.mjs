// A compact rendering of compiled PureScript values for tests: constructor
// names with their fields, arrays, and records with sorted keys. Spans are
// left out, so a shape states structure alone.
const isSpan = value => value !== null && typeof value === 'object'
  && 'start' in value && 'end' in value;

const fieldsOf = value => withoutRows(value, Object.keys(value)
  .filter(key => /^value\d+$/.test(key)).map(key => value[key])
  .filter(field => !isSpan(field)));

// Legacy FN001 shapes erase row annotations. FX001 tests inspect the rows
// separately; these assertions continue to pin all pre-existing structure.
const isRow = value => value !== null && typeof value === 'object'
  && value.constructor.name === 'Row';
const withoutRows = (value, fields) => fields.filter((field, index) =>
  !isRow(field) && !(value.constructor.name === 'FunRef' && index === 1)
  && !(value.constructor.name === 'TData' && index === 2
    && Array.isArray(field) && field.length === 0));

export const shape = value => {
  if (Array.isArray(value)) return `[${value.map(shape).join(', ')}]`;
  if (value === null || typeof value !== 'object') return String(value);
  const name = value.constructor.name;
  if (name === 'Object') {
    const keys = Object.keys(value).filter(key => !isSpan(value[key])).sort();
    return `{${keys.map(key => `${key}: ${shape(value[key])}`).join(', ')}}`;
  }
  const fields = fieldsOf(value);
  return fields.length === 0 ? name : `${name}(${fields.map(shape).join(', ')})`;
};
