import { FieldValue, Timestamp } from 'firebase-admin/firestore';

/** Shape of a bookings/{id} document. */
export interface BookingData {
  bookingId: string;
  customerId: string;
  technicianId?: string | null;
  categoryId: string;
  categoryName: string;
  description: string;
  status: string;
  isEmergency: boolean;
  scheduledAt: Timestamp | Date;
  createdAt: Timestamp | Date;
  updatedAt: Timestamp | Date;
  acceptedAt?: Timestamp | Date | null;
  etaMinutes?: number | null;
  cancellationReason?: string | null;
  location?: {
    geopoint?: { latitude: number; longitude: number };
    address?: string;
  };
  pricing?: {
    minCharge?: number;
    serviceCharge?: number;
    gstPercent?: number;
    estimatedTotal?: number;
  };
  payment?: {
    method?: string;
    status?: string;
    transactionId?: string;
    paidAt?: Timestamp | Date | null;
  };
  complaint?: {
    reason?: string;
    status?: string;
    resolution?: string | null;
    refundId?: string | null;
  };
  technicianInfo?: {
    name?: string;
    phone?: string;
    rating?: number;
  };
  matching?: {
    candidates?: string[];
    scores?: Record<string, number>;
    distances?: Record<string, number>;
    declined?: string[];
    attemptCount?: number;
    startedAt?: Timestamp | Date;
  };
}

export const serverNow = () => FieldValue.serverTimestamp();
