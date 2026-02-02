/**
 * Time-based permission helpers for sheet editing
 */

export type UserRole = 'branch_user' | 'supervisor' | 'field_supervisor' | 'admin';

/**
 * Check if a branch user can edit a sheet based on the sheet date
 * Branch users can edit until 11:59 PM of the same day
 */
export function canBranchUserEdit(sheetDate: string): boolean {
  // Parse sheet date (format: YYYY-MM-DD)
  const sheetDateStr = sheetDate.split('T')[0]; // Handle both date and datetime formats
  const todayStr = new Date().toISOString().split('T')[0];
  
  // console.log('Branch user edit check:', {
  //   sheetDate,
  //   sheetDateStr,
  //   todayStr,
  //   canEdit: sheetDateStr === todayStr
  // });
  
  // Branch users can edit only on the same day
  return sheetDateStr === todayStr;
}

/**
 * Check if a supervisor can edit a sheet based on the sheet date
 * Supervisors can edit from 12:00 AM of the next day onwards
 */
export function canSupervisorEdit(sheetDate: string): boolean {
  // Parse sheet date (format: YYYY-MM-DD)
  const sheetDateStr = sheetDate.split('T')[0]; // Handle both date and datetime formats
  const todayStr = new Date().toISOString().split('T')[0];
  
  // Supervisors can edit from the next day onwards
  return todayStr > sheetDateStr;
}

/**
 * Check if a user can edit a sheet based on their role and the sheet date
 */
export function canEditSheet(
  userRole: UserRole,
  sheetDate: string,
  _isLocked: boolean
): { canEdit: boolean; reason?: string } {
  // Admin can always edit
  if (userRole === 'admin') {
    return { canEdit: true };
  }
  
  // Time-based rules take precedence over locked status
  // Branch users can edit same-day sheets until 11:59 PM (even if submitted/locked)
  if (userRole === 'branch_user') {
    if (canBranchUserEdit(sheetDate)) {
      return { canEdit: true };
    }
    return { 
      canEdit: false, 
      reason: 'Branch users can only edit sheets on the same day before midnight' 
    };
  }
  
  // Supervisors can edit sheets from 12:00 AM onwards (next day)
  if (userRole === 'supervisor') {
    if (canSupervisorEdit(sheetDate)) {
      return { canEdit: true };
    }
    return { 
      canEdit: false, 
      reason: 'Supervisors can only edit sheets from the next day onwards' 
    };
  }
  
  // Field supervisors follow same rules as branch users
  if (userRole === 'field_supervisor') {
    if (canBranchUserEdit(sheetDate)) {
      return { canEdit: true };
    }
    return { 
      canEdit: false, 
      reason: 'Field supervisors can only edit sheets on the same day before midnight' 
    };
  }
  
  return { canEdit: false, reason: 'Unknown user role' };
}

/**
 * Get a user-friendly message about when a sheet can be edited
 */
export function getEditabilityMessage(
  userRole: UserRole,
  sheetDate: string,
  isLocked: boolean
): string {
  if (userRole === 'admin') {
    return 'You can edit this sheet.';
  }
  
  const sheet = new Date(sheetDate);
  const today = new Date();
  sheet.setHours(0, 0, 0, 0);
  today.setHours(0, 0, 0, 0);
  
  const submittedNote = isLocked ? ' (Submitted)' : '';
  
  if (userRole === 'branch_user') {
    if (sheet.getTime() === today.getTime()) {
      return `You can edit this sheet until 11:59 PM today${submittedNote}.`;
    } else if (sheet.getTime() > today.getTime()) {
      return 'This sheet is for a future date.';
    } else {
      return 'Branch users can only edit sheets on the same day. This sheet is now read-only.';
    }
  }
  
  if (userRole === 'supervisor') {
    if (today.getTime() > sheet.getTime()) {
      return `You can edit this sheet${submittedNote}. All edits are logged.`;
    } else if (sheet.getTime() === today.getTime()) {
      return 'Supervisors can edit this sheet from tomorrow (12:00 AM) onwards.';
    } else {
      return 'This sheet is for a future date.';
    }
  }
  
  if (userRole === 'field_supervisor') {
    if (sheet.getTime() === today.getTime()) {
      return `You can edit this sheet until 11:59 PM today${submittedNote}.`;
    } else if (sheet.getTime() > today.getTime()) {
      return 'This sheet is for a future date.';
    } else {
      return 'Field supervisors can only edit sheets on the same day. This sheet is now read-only.';
    }
  }
  
  return '';
}

/**
 * Check if a user role has access to admin features (items, management)
 */
export function hasAdminAccess(userRole: UserRole): boolean {
  return userRole === 'admin' || userRole === 'supervisor';
}

/**
 * Check if a user can access a specific route
 */
export function canAccessRoute(userRole: UserRole, route: string): boolean {
  // Admin routes - only admin and supervisor can access
  if (route.startsWith('/admin')) {
    return hasAdminAccess(userRole);
  }
  
  // Sheets routes - all roles can access
  if (route.startsWith('/sheets')) {
    return true;
  }
  
  // Default: allow access
  return true;
}
