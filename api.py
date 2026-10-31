"""
JSON API for the mobile app. Same phone number and password as the website
and USSD. Log in to get a token, then send it as:  Authorization: Bearer <token>
Changing the password signs every token out.

POST /api/register      {name, phone, password, district, consent: true} -> sends SMS code
POST /api/register/verify {phone, code} -> creates account and returns token
POST /api/login         {phone, password}
POST /api/forgot        {phone}                      sends an SMS code
POST /api/reset         {phone, code, password}
GET  /api/me
GET  /api/sources                                    markets and buyers
GET  /api/prices?crop=Maize                          price per kg with source, date and origin
GET  /api/weather
POST /api/report-price  {crop, market, price, unit}  market = name or id; unit kg | "50kg bag" | "90kg bag"
POST /api/calculate     {crop, quantity_kg, options: [{source_id, transport, other, price_override}], storage: {...}}
GET  /api/warnings                                    live warnings for your district
POST /api/alerts-sms    {enabled: true|false}        warning SMS on or off
GET/POST /api/price-alerts   {crop, target_per_kg, source_id?}      DELETE /api/price-alerts/<id>
GET  /api/symptoms                                   signs and typical pictures per crop
GET/POST /api/problems   {crop, signs, description}  or multipart with `photo`; returns guidance
GET  /api/problems/<id>, /api/cases/<id>/photo
GET  /api/listings                                   your listings
POST /api/listings      {crop, qty_kg, price_per_kg}
"""

import os
import uuid
from functools import wraps

from flask import Blueprint, jsonify, request, send_file

import advisor
import alerts
import auth
import cases
import db
import market
import mundasmart_ussd as ussd
import photos
import weather

bp = Blueprint("api", __name__)


def _err(code, status=400):
    return jsonify({"error": code, "message": auth.ERRORS.get(code, code)}), status


def _throttled(name, limit, window):
    return not db.rate_hit(f"api-{name}:{request.remote_addr}", limit, window)


def token_required(view):
    @wraps(view)
    def wrapper(*a, **kw):
        header = request.headers.get("Authorization", "")
        user = auth.user_from_api_token(header[7:]) if header.startswith("Bearer ") else None
        if not user:
            return jsonify({"error": "unauthorised", "message": "Please log in again."}), 401
        if (auth.is_admin(user) or auth.is_officer(user)) and request.endpoint != "api.me":
            return jsonify({"error": "role_restricted",
                            "message": "Staff accounts must use their role-specific web workspace."}), 403
        return view(user, *a, **kw)
    return wrapper


@bp.route("/register", methods=["POST"])
def register():
    if _throttled("register", 10, 3600):
        return _err("throttled", 429)
    d = request.get_json(silent=True) or {}
    if not isinstance(d, dict):
        return _err("invalid")
    phone, err = auth.register(d.get("name"), d.get("phone"), d.get("password"), d.get("district"),
                               "en", "app", d.get("consent") is True, email=d.get("email"),
                               account_type=d.get("account_type"))
    if err:
        return _err(err, 409 if err == "exists" else 400)
    return jsonify({"verification_required": True,
                    "message": auth.ERRORS["verify_sent"]}), 202


@bp.route("/register/verify", methods=["POST"])
def verify_registration():
    if _throttled("register-verify", 15, 3600):
        return _err("throttled", 429)
    d = request.get_json(silent=True) or {}
    if not isinstance(d, dict):
        return _err("verify_invalid")
    user, err = auth.verify_registration(d.get("phone"), d.get("code"))
    if err:
        return _err(err)
    return jsonify({"token": auth.make_api_token(user), "name": user["name"], "phone": user["phone"],
                    "account_type": user["account_type"]}), 201


@bp.route("/login", methods=["POST"])
def login():
    if _throttled("login", 30, 600):
        return _err("throttled", 429)
    d = request.get_json(silent=True) or {}
    user, err = auth.verify_login(d.get("phone", ""), d.get("password", ""))
    if err:
        return _err(err, 429 if err == "locked" else 401)
    if auth.is_admin(user) or auth.is_officer(user):
        return jsonify({"error": "role_restricted",
                        "message": "Staff accounts must use their role-specific web workspace."}), 403
    return jsonify({"token": auth.make_api_token(user), "name": user["name"], "phone": user["phone"],
                    "account_type": user["account_type"]})


@bp.route("/forgot", methods=["POST"])
def forgot():
    if _throttled("forgot", 6, 3600):
        return _err("throttled", 429)
    d = request.get_json(silent=True) or {}
    if auth.start_reset(d.get("phone", "")) == "phone":
        return _err("phone")
    return jsonify({"ok": True, "message": "If this number is registered, a code has been sent by SMS."})


@bp.route("/reset", methods=["POST"])
def reset():
    if _throttled("reset", 15, 3600):
        return _err("throttled", 429)
    d = request.get_json(silent=True) or {}
    ok, err = auth.finish_reset(d.get("phone", ""), d.get("code", ""), d.get("password", ""))
    if not ok:
        return _err(err)
    return jsonify({"ok": True})


@bp.route("/me")
@token_required
def me(user):
    return jsonify({"name": user["name"], "email": user["email"], "phone": user["phone"],
                    "district": user["district"], "account_type": user["account_type"]})


@bp.route("/sources")
@token_required
def sources(user):
    return jsonify({"sources": [{"id": s["id"], "name": s["name"], "kind": s["kind"], "district": s["district"],
                                 "fee_pct": s["fee_pct"], "handling_per_kg": s["handling_per_kg"]}
                                for s in db.list_sources()], "units": market.UNITS})


@bp.route("/prices")
@token_required
def prices(user):
    wanted = request.args.get("crop")
    out = []
    for crop in ussd.CROPS.values():
        if wanted and wanted != crop:
            continue
        for r in market.price_table(crop):
            out.append({"crop": crop, "source_id": r["source_id"], "source": r["source"], "kind": r["kind"],
                        "district": r["district"], "price_per_kg": round(r["price_per_kg"], 2),
                        "price_per_50kg_bag": round(r["price_per_kg"] * 50, 2), "as_of": r["as_of"],
                        "origin": r["origin"], "origin_label": r["origin_label"], "reports_last_7_days": r["n_recent"],
                        "valid_until": r["valid_until"], "outlook": r["direction"],
                        "expected_in_7_days_per_kg": round(r["expected_per_kg"], 2) if r["expected_per_kg"] else None})
    return jsonify({"prices": out})


@bp.route("/weather")
@token_required
def weather_alert(user):
    district = request.args.get("district") or user["district"]
    if district not in weather.COORDS:
        return jsonify({"error": "district", "message": "Unknown district."}), 400
    return jsonify({"district": district, "alert": weather.alert_text(district)})


@bp.route("/report-price", methods=["POST"])
@token_required
def report_price(user):
    d = request.get_json(silent=True) or {}
    src = next((s for s in db.list_sources("market")
                if s["id"] == d.get("source_id") or s["name"] == d.get("market") or str(s["id"]) == str(d.get("market"))), None)
    unit = d.get("unit", "kg")
    try:
        amount = market.parse_number(d.get("price"), 0.01, None, "Price")
        per_kg = market.to_per_kg(amount, unit)
    except ValueError:
        return jsonify({"error": "invalid", "message": "Invalid price or unit."}), 400
    if d.get("crop") not in ussd.CROPS.values() or not src:
        return jsonify({"error": "invalid", "message": "Unknown crop or market."}), 400
    if db.add_price(d["crop"], str(src["id"]), per_kg, phone=user["phone"], unit=unit, unit_price=amount) is None:
        return jsonify({"error": "invalid", "message": "Price invalid, or daily limit reached."}), 400
    return jsonify({"ok": True}), 201


@bp.route("/calculate", methods=["POST"])
@token_required
def calculate(user):
    d = request.get_json(silent=True) or {}
    if d.get("crop") not in ussd.CROPS.values():
        return jsonify({"error": "invalid", "message": "Unknown crop."}), 400
    try:
        qty = market.parse_number(d.get("quantity_kg"), 0.1, 100000, "Quantity")
        options = [{"source_id": int(o["source_id"]), "transport": o.get("transport") or 0,
                    "other": o.get("other") or 0, "price_override": o.get("price_override")}
                   for o in (d.get("options") or [])]
        if not options:
            raise ValueError("Give at least one option.")
        results, skipped = market.compare(d["crop"], qty, options, d.get("storage"))
    except (ValueError, KeyError, TypeError) as exc:
        return jsonify({"error": "invalid", "message": str(exc)}), 400
    return jsonify({"skipped": skipped, "results": [
        {"rank": r["rank"], "option": r["label"], "scenario": r["scenario"], "kind": r["kind"],
         "price_per_kg": round(r["price_per_kg"], 2), "revenue": round(r["revenue"], 2),
         "costs": [{"item": k, "amount": round(v, 2)} for k, v in r["costs"]],
         "total_costs": round(r["total_costs"], 2), "net": round(r["net"], 2),
         "net_per_kg": round(r["net_per_kg"], 2), "assumptions": r["assumptions"],
         "price_origin": r["origin"]} for r in results]})


@bp.route("/price-alerts", methods=["GET", "POST"])
@token_required
def price_alerts(user):
    if request.method == "GET":
        return jsonify({"alerts": [{"id": a["id"], "crop": a["crop"], "source": a["source_name"] or "any",
                                    "target_per_kg": a["target_per_kg"], "active": bool(a["active"]),
                                    "triggered_at": a["triggered_at"]} for a in db.list_price_alerts(user["id"])]})
    d = request.get_json(silent=True) or {}
    try:
        target = market.parse_number(d.get("target_per_kg"), 0.01, db.MAX_PRICE, "Target")
        sid = int(d["source_id"]) if d.get("source_id") else None
    except (ValueError, TypeError):
        return jsonify({"error": "invalid", "message": "Invalid target price."}), 400
    if d.get("crop") not in ussd.CROPS.values() or (sid and not db.get_source(sid)):
        return jsonify({"error": "invalid", "message": "Unknown crop or source."}), 400
    new_id = db.add_price_alert(user["id"], d["crop"], sid, target)
    if not new_id:
        return jsonify({"error": "limit", "message": f"You can keep up to {db.MAX_ACTIVE_PRICE_ALERTS} active targets."}), 400
    return jsonify({"ok": True, "id": new_id}), 201


@bp.route("/price-alerts/<int:alert_id>", methods=["DELETE"])
@token_required
def delete_price_alert(user, alert_id):
    return jsonify({"ok": True}) if db.delete_price_alert(alert_id, user["id"]) else (jsonify({"error": "not_found"}), 404)


@bp.route("/symptoms")
def symptoms():
    """Signs a farmer can tick, and the typical pictures per crop."""
    return jsonify({"signs": [{"code": k, "label": v} for k, v in advisor.TAGS.items()],
                    "crops": {c: [{"label": label, "signs": tags} for label, tags in items]
                              for c, items in advisor.PRESENTATIONS.items()}})


def _case_json(k, full=False):
    pending_review = bool(k["suggested_reply"] and k["status"] == "new")
    out = {"id": k["id"], "ref": k["ref"], "crop": k["crop"], "channel": k["channel"], "created_at": k["created_at"],
           "likely_problem": None, "status": k["status"],
           "waiting_for_officer": k["status"] == "new", "has_photo": bool(k["photo"]),
           "officer_reply": k["reply"], "replied_at": k["replied_at"]}
    if full:
        out["signs"] = [t for t in (k["tags"] or "").split(",") if t]
        out["description"] = k["description"]
        if pending_review:
            out["response_status"] = "awaiting_human_review"
            out["message"] = "A high-confidence disease suggestion is waiting for extension officer approval."
        if k["photo"]:
            out["photo_url"] = f"/api/cases/{k['id']}/photo"
    return out


def _guidance_json(r):
    return {"confident": r["confident"], "confidence": r["confidence"], "confidence_label": r["label"],
            "likely_problem": r["name"], "summary": r["short"], "steps": r["steps"],
            "possible": [c["name"] for c in r["candidates"]], "weather_notes": r["weather_notes"],
            "referred_to_officer": r["refer"], "photo_note": r.get("photo_note"), "referral_reason": r["refer_reason"], "safety": r["safety"],
            "disclaimer": r["disclaimer"]}


@bp.route("/problems", methods=["GET", "POST"])
@token_required
def problems(user):
    """POST a problem as JSON {crop, signs: [...], description} or as multipart with an optional `photo`."""
    if request.method == "GET":
        return jsonify({"cases": [_case_json(k) for k in db.list_cases(user_id=user["id"], limit=50)]})
    if _throttled("problems", 40, 3600):
        return _err("throttled", 429)
    if request.is_json:
        d = request.get_json(silent=True) or {}
        signs, upload = d.get("signs") or [], None
    else:
        d = request.form
        signs, upload = request.form.getlist("signs"), request.files.get("photo")
    if d.get("crop") not in ussd.CROPS.values() or not isinstance(signs, list):
        return jsonify({"error": "invalid", "message": "Unknown crop."}), 400
    try:
        photo = photos.save(upload)
    except photos.PhotoError as exc:
        return jsonify({"error": "photo", "message": str(exc)}), 400
    cid, ref, result = cases.submit(user, d["crop"], [str(s) for s in signs], str(d.get("description") or ""), photo, "app")
    if cid is None:
        if photo and photos.path(photo):
            os.remove(photos.path(photo))
        return jsonify({"error": "limit", "message": "You have reached today's limit for problem reports."}), 429
    payload = {"ok": True, "id": cid, "ref": ref}
    if result.get("pending_review"):
        payload["response_status"] = "awaiting_human_review"
        payload["message"] = "A high-confidence disease suggestion is waiting for extension officer approval."
    else:
        payload["guidance"] = _guidance_json(result)
    return jsonify(payload), 201


@bp.route("/problems/<int:case_id>")
@token_required
def problem(user, case_id):
    k = db.get_case(case_id)
    if not k or k["user_id"] != user["id"]:
        return jsonify({"error": "not_found"}), 404
    return jsonify(_case_json(k, full=True))


@bp.route("/cases/<int:case_id>/photo")
@token_required
def problem_photo(user, case_id):
    k = db.get_case(case_id)
    path = photos.path(k["photo"]) if k and k["photo"] else None
    if not path or k["user_id"] != user["id"]:
        return jsonify({"error": "not_found"}), 404
    resp = send_file(path, mimetype="image/jpeg", max_age=0)
    resp.headers["Cache-Control"] = "private, no-store"
    return resp


@bp.route("/warnings")
@token_required
def warnings(user):
    """Live approved warnings for the farmer's district. Opening this marks the in-app notices as seen."""
    return jsonify({"district": user["district"], "sms_alerts": bool(user["alerts_sms"]), "warnings": [
        {"id": w["id"], "type": w["kind"], "type_label": w["kind_label"], "level": w["severity"], "headline": w["headline"],
         "advice": w["advice"], "districts": w["district_list"], "issued_at": w["issued_at"], "updated_at": w["updated_at"],
         "version": w["version"], "expires_at": w["expires_at"]} for w in alerts.inbox(user)]})


@bp.route("/alerts-sms", methods=["POST"])
@token_required
def alerts_sms(user):
    d = request.get_json(silent=True) or {}
    if not isinstance(d.get("enabled"), bool):
        return jsonify({"error": "invalid", "message": "Send {\"enabled\": true or false}."}), 400
    alerts.set_sms_alerts(user["id"], d["enabled"])
    return jsonify({"ok": True, "sms_alerts": d["enabled"]})


@bp.route("/listings", methods=["GET", "POST"])
@token_required
def listings(user):
    if request.method == "GET":
        rows = db.list_listings(limit=50, user_id=user["id"])
        return jsonify({"listings": [{"ref": r["ref"], "crop": r["crop"], "qty_kg": r["qty_kg"],
                                      "price_per_kg": r["price_per_kg"], "status": r["status"],
                                      "created_at": r["created_at"]} for r in rows]})
    if user["account_type"] not in ("seller", "both"):
        return jsonify({"error": "role_restricted", "message": "A seller account is required to create listings."}), 403
    d = request.get_json(silent=True) or {}
    try:
        qty, price = float(d.get("qty_kg")), float(d.get("price_per_kg"))
    except (TypeError, ValueError):
        qty = price = 0
    code = uuid.uuid4().hex[:6].upper()
    if d.get("crop") not in ussd.CROPS.values() or not db.add_listing(user["id"], code, d["crop"], qty, price):
        return jsonify({"error": "invalid", "message": "Invalid listing, or daily limit reached."}), 400
    return jsonify({"ok": True, "ref": code}), 201
